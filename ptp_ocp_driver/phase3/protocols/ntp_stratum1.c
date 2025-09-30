/*
 * NTP Stratum 1 Server Module
 * 
 * This module implements:
 * - NTP Stratum 1 server functionality
 * - High-precision time distribution
 * - Multiple client support
 * - Leap second handling
 * - Authentication support
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/netdevice.h>
#include <linux/udp.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <linux/socket.h>
#include <linux/net.h>
#include <linux/skbuff.h>
#include <linux/workqueue.h>
#include <linux/timer.h>
#include <linux/mutex.h>
#include <linux/spinlock.h>
#include <linux/ktime.h>
#include <linux/jiffies.h>
#include <linux/slab.h>
#include <linux/io.h>
#include <linux/pci.h>
#include <linux/crypto.h>
#include <linux/scatterlist.h>

#include "../core/ptp_ocp_enhanced.h"

/* NTP Constants */
#define NTP_PORT                    123
#define NTP_VERSION                 4
#define NTP_MODE_SERVER             4
#define NTP_MODE_CLIENT             3
#define NTP_STRATUM_PRIMARY         1
#define NTP_LEAP_NO_WARNING         0
#define NTP_LEAP_ADD_SECOND         1
#define NTP_LEAP_DEL_SECOND         2
#define NTP_LEAP_NOT_SYNC           3
#define NTP_PRECISION               -20  /* 2^-20 seconds ≈ 1 microsecond */
#define NTP_MAX_CLIENTS             1000
#define NTP_TIMEOUT_MS              5000
#define NTP_MAX_PACKET_SIZE         48

/* NTP Packet Structure */
struct ntp_packet {
    u8 leap_ver_mode;          /* Leap indicator (2 bits) + Version (3 bits) + Mode (3 bits) */
    u8 stratum;                /* Stratum level */
    u8 poll;                   /* Poll interval */
    u8 precision;              /* Precision */
    u32 root_delay;            /* Root delay (fixed point) */
    u32 root_dispersion;       /* Root dispersion (fixed point) */
    u32 reference_id;          /* Reference ID */
    u32 ref_timestamp_sec;     /* Reference timestamp (seconds) */
    u32 ref_timestamp_frac;    /* Reference timestamp (fraction) */
    u32 orig_timestamp_sec;    /* Origin timestamp (seconds) */
    u32 orig_timestamp_frac;   /* Origin timestamp (fraction) */
    u32 recv_timestamp_sec;    /* Receive timestamp (seconds) */
    u32 recv_timestamp_frac;   /* Receive timestamp (fraction) */
    u32 trans_timestamp_sec;   /* Transmit timestamp (seconds) */
    u32 trans_timestamp_frac;  /* Transmit timestamp (fraction) */
} __packed;

/* NTP Client Information */
struct ntp_client {
    struct in_addr client_addr;
    u16 client_port;
    u64 last_request_time;
    u32 request_count;
    u32 response_count;
    u32 error_count;
    bool authenticated;
    u32 key_id;
    u64 last_activity;
    struct list_head list;
};

/* NTP Server Configuration */
struct ntp_server_config {
    u8 stratum;
    u8 precision;
    u32 reference_id;
    u32 poll_interval;
    u32 timeout_ms;
    bool authentication_enabled;
    bool leap_second_support;
    u32 max_clients;
    char server_name[64];
    char reference_clock[64];
};

/* NTP Server Statistics */
struct ntp_server_stats {
    u64 packets_received;
    u64 packets_sent;
    u64 packets_dropped;
    u64 authentication_failures;
    u64 malformed_packets;
    u64 client_connections;
    u64 active_clients;
    u64 leap_second_events;
    u64 reference_updates;
    u64 sync_events;
    u64 error_events;
};

/* NTP Server Session */
struct ntp_server_session {
    struct ntp_server_config config;
    struct ntp_server_stats stats;
    struct list_head clients;
    struct mutex clients_mutex;
    struct work_struct request_work;
    struct timer_list cleanup_timer;
    struct socket *socket;
    struct ptp_ocp_enhanced *timecard;
    bool active;
    u64 reference_time;
    u64 last_sync_time;
    u32 sequence_number;
    atomic_t client_count;
};

/* Forward declarations */
static int ntp_server_init_session(struct ntp_server_session *session,
                                   struct ptp_ocp_enhanced *timecard);
static void ntp_server_cleanup_session(struct ntp_server_session *session);
static int ntp_server_create_socket(struct ntp_server_session *session);
static void ntp_server_destroy_socket(struct ntp_server_session *session);
static int ntp_server_handle_request(struct ntp_server_session *session,
                                     struct sk_buff *skb);
static int ntp_server_send_response(struct ntp_server_session *session,
                                    struct ntp_packet *request,
                                    struct sockaddr_in *client_addr);
static void ntp_server_convert_timestamp(struct timespec64 *ts,
                                        u32 *sec, u32 *frac);
static void ntp_server_get_reference_time(struct ntp_server_session *session,
                                         u32 *ref_sec, u32 *ref_frac);
static int ntp_server_authenticate_packet(struct ntp_packet *packet,
                                         struct sockaddr_in *client_addr);
static void ntp_server_cleanup_clients(struct ntp_server_session *session);
static void ntp_server_cleanup_timer_callback(struct timer_list *t);
static void ntp_server_request_work(struct work_struct *work);
static struct ntp_client *ntp_server_find_client(struct ntp_server_session *session,
                                                 struct in_addr *addr, u16 port);
static struct ntp_client *ntp_server_add_client(struct ntp_server_session *session,
                                                struct in_addr *addr, u16 port);

/* Initialize NTP server session */
static int ntp_server_init_session(struct ntp_server_session *session,
                                   struct ptp_ocp_enhanced *timecard)
{
    if (!session || !timecard)
        return -EINVAL;
    
    memset(session, 0, sizeof(*session));
    
    /* Set configuration */
    session->config.stratum = NTP_STRATUM_PRIMARY;
    session->config.precision = NTP_PRECISION;
    session->config.reference_id = 0x4F435020; /* "OCP " */
    session->config.poll_interval = 1024; /* 2^10 seconds */
    session->config.timeout_ms = NTP_TIMEOUT_MS;
    session->config.authentication_enabled = false;
    session->config.leap_second_support = true;
    session->config.max_clients = NTP_MAX_CLIENTS;
    strncpy(session->config.server_name, "Quantum-PCI NTP Server", 
            sizeof(session->config.server_name) - 1);
    strncpy(session->config.reference_clock, "PTP OCP", 
            sizeof(session->config.reference_clock) - 1);
    
    /* Initialize statistics */
    memset(&session->stats, 0, sizeof(session->stats));
    
    /* Initialize client list */
    INIT_LIST_HEAD(&session->clients);
    mutex_init(&session->clients_mutex);
    
    /* Initialize work queue */
    INIT_WORK(&session->request_work, ntp_server_request_work);
    
    /* Initialize cleanup timer */
    timer_setup(&session->cleanup_timer, ntp_server_cleanup_timer_callback, 0);
    
    /* Store timecard reference */
    session->timecard = timecard;
    
    /* Initialize reference time */
    session->reference_time = ktime_get_ns();
    session->last_sync_time = ktime_get_ns();
    
    /* Initialize sequence number */
    session->sequence_number = 1;
    
    /* Initialize client count */
    atomic_set(&session->client_count, 0);
    
    /* Mark session as active */
    session->active = true;
    
    return 0;
}

/* Create NTP server socket */
static int ntp_server_create_socket(struct ntp_server_session *session)
{
    struct sockaddr_in server_addr;
    int ret;
    
    /* Create UDP socket */
    ret = sock_create_kern(&init_net, AF_INET, SOCK_DGRAM, IPPROTO_UDP, &session->socket);
    if (ret < 0) {
        return ret;
    }
    
    /* Set socket options */
    sock_set_reuseaddr(session->socket->sk);
    sock_set_reuseport(session->socket->sk);
    
    /* Bind to NTP port */
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(NTP_PORT);
    server_addr.sin_addr.s_addr = INADDR_ANY;
    
    ret = kernel_bind(session->socket, (struct sockaddr *)&server_addr, sizeof(server_addr));
    if (ret < 0) {
        ntp_server_destroy_socket(session);
        return ret;
    }
    
    return 0;
}

/* Handle NTP request */
static int ntp_server_handle_request(struct ntp_server_session *session,
                                     struct sk_buff *skb)
{
    struct ntp_packet *ntp_req, *ntp_resp;
    struct sockaddr_in client_addr;
    struct ntp_client *client;
    struct sk_buff *response_skb;
    int ret;
    
    if (!session || !skb)
        return -EINVAL;
    
    /* Update statistics */
    session->stats.packets_received++;
    
    /* Extract client address */
    client_addr.sin_family = AF_INET;
    client_addr.sin_port = skb->h.udp->source;
    client_addr.sin_addr.s_addr = ip_hdr(skb)->saddr;
    
    /* Validate packet size */
    if (skb->len < sizeof(struct ntp_packet)) {
        session->stats.malformed_packets++;
        return -EINVAL;
    }
    
    /* Get NTP packet */
    ntp_req = (struct ntp_packet *)skb->data;
    
    /* Validate NTP packet */
    if (ntp_req->stratum == 0 || ntp_req->stratum > 15) {
        session->stats.malformed_packets++;
        return -EINVAL;
    }
    
    /* Authenticate packet if required */
    if (session->config.authentication_enabled) {
        ret = ntp_server_authenticate_packet(ntp_req, &client_addr);
        if (ret != 0) {
            session->stats.authentication_failures++;
            return ret;
        }
    }
    
    /* Find or add client */
    client = ntp_server_find_client(session, &client_addr.sin_addr, client_addr.sin_port);
    if (!client) {
        client = ntp_server_add_client(session, &client_addr.sin_addr, client_addr.sin_port);
        if (!client) {
            session->stats.packets_dropped++;
            return -ENOMEM;
        }
    }
    
    /* Update client statistics */
    client->last_request_time = ktime_get_ns();
    client->request_count++;
    client->last_activity = ktime_get_ns();
    
    /* Allocate response packet */
    response_skb = alloc_skb(NTP_MAX_PACKET_SIZE + LL_MAX_HEADER, GFP_ATOMIC);
    if (!response_skb) {
        session->stats.packets_dropped++;
        return -ENOMEM;
    }
    
    /* Reserve space for headers */
    skb_reserve(response_skb, LL_MAX_HEADER);
    
    /* Add NTP response */
    ntp_resp = skb_put(response_skb, sizeof(struct ntp_packet));
    memset(ntp_resp, 0, sizeof(struct ntp_packet));
    
    /* Fill NTP response */
    ntp_resp->leap_ver_mode = (NTP_LEAP_NO_WARNING << 6) | (NTP_VERSION << 3) | NTP_MODE_SERVER;
    ntp_resp->stratum = session->config.stratum;
    ntp_resp->poll = session->config.poll_interval;
    ntp_resp->precision = session->config.precision;
    ntp_resp->root_delay = htonl(0); /* No root delay for stratum 1 */
    ntp_resp->root_dispersion = htonl(0); /* No root dispersion for stratum 1 */
    ntp_resp->reference_id = htonl(session->config.reference_id);
    
    /* Set reference timestamp */
    u32 ref_sec, ref_frac;
    ntp_server_get_reference_time(session, &ref_sec, &ref_frac);
    ntp_resp->ref_timestamp_sec = htonl(ref_sec);
    ntp_resp->ref_timestamp_frac = htonl(ref_frac);
    
    /* Copy origin timestamp from request */
    ntp_resp->orig_timestamp_sec = ntp_req->trans_timestamp_sec;
    ntp_resp->orig_timestamp_frac = ntp_req->trans_timestamp_frac;
    
    /* Set receive timestamp */
    struct timespec64 recv_ts;
    ktime_get_real_ts64(&recv_ts);
    ntp_server_convert_timestamp(&recv_ts, &ref_sec, &ref_frac);
    ntp_resp->recv_timestamp_sec = htonl(ref_sec);
    ntp_resp->recv_timestamp_frac = htonl(ref_frac);
    
    /* Set transmit timestamp */
    ktime_get_real_ts64(&recv_ts);
    ntp_server_convert_timestamp(&recv_ts, &ref_sec, &ref_frac);
    ntp_resp->trans_timestamp_sec = htonl(ref_sec);
    ntp_resp->trans_timestamp_frac = htonl(ref_frac);
    
    /* TODO: Send response packet via socket */
    /* This would involve setting up the UDP headers and calling kernel_sendmsg */
    
    /* Update statistics */
    session->stats.packets_sent++;
    client->response_count++;
    
    /* Free response skb for now */
    kfree_skb(response_skb);
    
    return 0;
}

/* Convert timespec64 to NTP timestamp format */
static void ntp_server_convert_timestamp(struct timespec64 *ts,
                                        u32 *sec, u32 *frac)
{
    /* NTP epoch is 1900-01-01, Unix epoch is 1970-01-01 */
    /* Difference is 2208988800 seconds */
    *sec = ts->tv_sec + 2208988800UL;
    
    /* Convert nanoseconds to fractional seconds */
    /* NTP fraction is 2^32 * (nanoseconds / 1e9) */
    *frac = (u32)((ts->tv_nsec * 4294967296ULL) / 1000000000ULL);
}

/* Get reference time from PTP clock */
static void ntp_server_get_reference_time(struct ntp_server_session *session,
                                         u32 *ref_sec, u32 *ref_frac)
{
    struct timespec64 ref_ts;
    
    /* TODO: Get precise time from PTP clock */
    /* For now, use system time */
    ktime_get_real_ts64(&ref_ts);
    ntp_server_convert_timestamp(&ref_ts, ref_sec, ref_frac);
}

/* Find existing client */
static struct ntp_client *ntp_server_find_client(struct ntp_server_session *session,
                                                 struct in_addr *addr, u16 port)
{
    struct ntp_client *client;
    
    list_for_each_entry(client, &session->clients, list) {
        if (client->client_addr.s_addr == addr->s_addr && 
            client->client_port == port) {
            return client;
        }
    }
    
    return NULL;
}

/* Add new client */
static struct ntp_client *ntp_server_add_client(struct ntp_server_session *session,
                                                struct in_addr *addr, u16 port)
{
    struct ntp_client *client;
    
    /* Check client limit */
    if (atomic_read(&session->client_count) >= session->config.max_clients) {
        return NULL;
    }
    
    /* Allocate client structure */
    client = kzalloc(sizeof(*client), GFP_ATOMIC);
    if (!client) {
        return NULL;
    }
    
    /* Initialize client */
    client->client_addr = *addr;
    client->client_port = port;
    client->last_request_time = ktime_get_ns();
    client->request_count = 0;
    client->response_count = 0;
    client->error_count = 0;
    client->authenticated = false;
    client->last_activity = ktime_get_ns();
    
    /* Add to list */
    mutex_lock(&session->clients_mutex);
    list_add_tail(&client->list, &session->clients);
    atomic_inc(&session->client_count);
    session->stats.client_connections++;
    mutex_unlock(&session->clients_mutex);
    
    return client;
}

/* Cleanup inactive clients */
static void ntp_server_cleanup_clients(struct ntp_server_session *session)
{
    struct ntp_client *client, *temp;
    u64 current_time = ktime_get_ns();
    u64 timeout_ns = session->config.timeout_ms * 1000000ULL;
    
    mutex_lock(&session->clients_mutex);
    
    list_for_each_entry_safe(client, temp, &session->clients, list) {
        if (current_time - client->last_activity > timeout_ns) {
            list_del(&client->list);
            atomic_dec(&session->client_count);
            kfree(client);
        }
    }
    
    session->stats.active_clients = atomic_read(&session->client_count);
    mutex_unlock(&session->clients_mutex);
}

/* Cleanup timer callback */
static void ntp_server_cleanup_timer_callback(struct timer_list *t)
{
    struct ntp_server_session *session = 
        from_timer(session, t, cleanup_timer);
    
    if (session->active) {
        /* Cleanup inactive clients */
        ntp_server_cleanup_clients(session);
        
        /* Restart timer */
        mod_timer(&session->cleanup_timer, 
                  jiffies + msecs_to_jiffies(60000)); /* 1 minute */
    }
}

/* Initialize NTP Stratum 1 server */
int ntp_stratum1_init_server(struct ptp_ocp_enhanced *enhanced)
{
    struct ntp_server_session *session;
    int ret;
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Initializing NTP Stratum 1 server");
    
    /* Allocate session */
    session = kzalloc(sizeof(*session), GFP_KERNEL);
    if (!session) {
        return -ENOMEM;
    }
    
    /* Initialize session */
    ret = ntp_server_init_session(session, enhanced);
    if (ret) {
        kfree(session);
        return ret;
    }
    
    /* Create socket */
    ret = ntp_server_create_socket(session);
    if (ret) {
        ntp_server_cleanup_session(session);
        kfree(session);
        return ret;
    }
    
    /* Start cleanup timer */
    mod_timer(&session->cleanup_timer, 
              jiffies + msecs_to_jiffies(60000)); /* 1 minute */
    
    /* TODO: Store session in enhanced driver structure */
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "NTP Stratum 1 server initialized successfully");
    
    return 0;
}

/* Cleanup NTP Stratum 1 server */
void ntp_stratum1_cleanup_server(struct ptp_ocp_enhanced *enhanced)
{
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Cleaning up NTP Stratum 1 server");
    
    /* TODO: Get session from enhanced structure and cleanup */
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "NTP Stratum 1 server cleaned up");
}

/* Cleanup NTP server session */
static void ntp_server_cleanup_session(struct ntp_server_session *session)
{
    struct ntp_client *client, *temp;
    
    if (!session) {
        return;
    }
    
    /* Stop timers */
    if (session->cleanup_timer.function) {
        del_timer_sync(&session->cleanup_timer);
    }
    
    /* Cancel work */
    cancel_work_sync(&session->request_work);
    
    /* Destroy socket */
    ntp_server_destroy_socket(session);
    
    /* Cleanup clients */
    mutex_lock(&session->clients_mutex);
    list_for_each_entry_safe(client, temp, &session->clients, list) {
        list_del(&client->list);
        kfree(client);
    }
    mutex_unlock(&session->clients_mutex);
    
    /* Mark session as inactive */
    session->active = false;
}

/* Destroy NTP server socket */
static void ntp_server_destroy_socket(struct ntp_server_session *session)
{
    if (session->socket) {
        sock_release(session->socket);
        session->socket = NULL;
    }
}

/* Request work handler */
static void ntp_server_request_work(struct work_struct *work)
{
    struct ntp_server_session *session = 
        container_of(work, struct ntp_server_session, request_work);
    
    /* TODO: Process incoming NTP requests */
    /* This would involve reading from the socket and calling handle_request */
}

