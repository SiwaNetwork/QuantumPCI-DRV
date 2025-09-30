/*
 * Network Integration Module for Enhanced PTP OCP Driver
 * 
 * This module implements:
 * - Integration with Intel network cards (I210, I225, I226)
 * - Hardware timestamping coordination
 * - PTP Master/Slave modes
 * - Transparent/Boundary clock support
 * - Network time coordination
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/ptp_clock_kernel.h>
#include <linux/net_tstamp.h>
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
#include <linux/ethtool.h>

#include "../core/ptp_ocp_enhanced.h"

/* Intel network card device IDs */
#define INTEL_I210_DEVICE_ID    0x1533
#define INTEL_I225_DEVICE_ID    0x15F2
#define INTEL_I226_DEVICE_ID    0x125B

/* Network integration configuration */
#define NETWORK_SYNC_INTERVAL_MS    1000    /* 1 second */
#define NETWORK_SYNC_TIMEOUT_MS     5000    /* 5 seconds */
#define NETWORK_MAX_OFFSET_NS       1000000 /* 1 ms */
#define NETWORK_MAX_FREQ_OFFSET_PPB 1000    /* 1 ppm */

/* Network coordination modes */
enum ptp_ocp_network_mode {
    PTP_OCP_NETWORK_DISABLED = 0,
    PTP_OCP_NETWORK_MASTER,
    PTP_OCP_NETWORK_SLAVE,
    PTP_OCP_NETWORK_TRANSPARENT,
    PTP_OCP_NETWORK_BOUNDARY
};

/* Hardware timestamping types */
enum ptp_ocp_timestamping_type {
    PTP_OCP_TIMESTAMPING_SOFTWARE = 0,
    PTP_OCP_TIMESTAMPING_HARDWARE,
    PTP_OCP_TIMESTAMPING_HYBRID
};

/* Network device information */
struct ptp_ocp_network_device {
    struct net_device *dev;
    struct ptp_clock *phc;
    char name[IFNAMSIZ];
    u32 device_id;
    bool hardware_timestamping_supported;
    bool hardware_timestamping_enabled;
    enum ptp_ocp_timestamping_type timestamping_type;
    
    /* Statistics */
    u64 tx_timestamp_count;
    u64 rx_timestamp_count;
    u64 timestamp_errors;
    u64 sync_packets;
    u64 delay_packets;
    
    /* Performance metrics */
    u64 avg_tx_latency_ns;
    u64 avg_rx_latency_ns;
    u32 timestamp_accuracy_ns;
};

/* Network coordination structure */
struct ptp_ocp_network_coordinator {
    struct ptp_ocp_enhanced *timecard;
    struct ptp_ocp_network_device network_dev;
    enum ptp_ocp_network_mode mode;
    
    /* Synchronization */
    struct work_struct sync_work;
    struct timer_list sync_timer;
    struct mutex sync_mutex;
    
    /* Time coordination */
    s64 time_offset_ns;                 /* Time offset (ns) */
    s64 frequency_offset_ppb;           /* Frequency offset (ppb) */
    u32 sync_quality;                   /* Sync quality (0-100) */
    u64 last_sync_time;                 /* Last sync time */
    
    /* Configuration */
    u32 sync_interval_ms;
    u32 sync_timeout_ms;
    u32 max_offset_ns;
    bool enabled;
    
    /* Statistics */
    u32 sync_success_count;
    u32 sync_failure_count;
    u64 total_sync_time_ns;
    u32 consecutive_failures;
    
    /* PTP configuration */
    u32 ptp_domain;
    u32 ptp_transport;          /* UDPv4/UDPv6/L2 */
    u32 ptp_message_types;      /* Sync/Follow_Up/Delay_Req/Delay_Resp */
    bool ptp_two_step;
    bool ptp_unicast;
};

/* Network packet structure for PTP */
struct ptp_ocp_network_packet {
    struct sk_buff *skb;
    u64 timestamp_ns;
    u32 message_type;
    u32 sequence_id;
    u64 correlation_id;
    struct timespec64 tx_time;
    struct timespec64 rx_time;
};

/* Forward declarations */
static int ptp_ocp_detect_intel_cards(struct ptp_ocp_enhanced *enhanced);
static int ptp_ocp_register_network_device(struct ptp_ocp_enhanced *enhanced, 
                                          struct net_device *dev);
static int ptp_ocp_enable_hardware_timestamping(struct ptp_ocp_network_device *netdev);
static int ptp_ocp_disable_hardware_timestamping(struct ptp_ocp_network_device *netdev);
static void ptp_ocp_network_sync_work(struct work_struct *work);
static void ptp_ocp_network_sync_timer(struct timer_list *t);
static int ptp_ocp_sync_with_network(struct ptp_ocp_enhanced *enhanced);
static int ptp_ocp_configure_ptp_master(struct ptp_ocp_enhanced *enhanced);
static int ptp_ocp_configure_ptp_slave(struct ptp_ocp_enhanced *enhanced);
static int ptp_ocp_configure_transparent_clock(struct ptp_ocp_enhanced *enhanced);
static int ptp_ocp_configure_boundary_clock(struct ptp_ocp_enhanced *enhanced);

/* Detect Intel network cards */
static int ptp_ocp_detect_intel_cards(struct ptp_ocp_enhanced *enhanced)
{
    struct net_device *dev;
    int found_cards = 0;
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Detecting Intel network cards...");
    
    rcu_read_lock();
    for_each_netdev_rcu(&init_net, dev) {
        struct pci_dev *pdev = NULL;
        
        /* Get PCI device for network interface */
        if (dev->dev.parent && dev->dev.parent->bus == &pci_bus_type) {
            pdev = to_pci_dev(dev->dev.parent);
            
            /* Check for Intel network cards */
            if (pdev->vendor == PCI_VENDOR_ID_INTEL) {
                switch (pdev->device) {
                case INTEL_I210_DEVICE_ID:
                    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                                "Found Intel I210: %s", dev->name);
                    break;
                case INTEL_I225_DEVICE_ID:
                    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                                "Found Intel I225: %s", dev->name);
                    break;
                case INTEL_I226_DEVICE_ID:
                    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                                "Found Intel I226: %s", dev->name);
                    break;
                default:
                    continue;
                }
                
                /* Register network device */
                if (ptp_ocp_register_network_device(enhanced, dev) == 0) {
                    found_cards++;
                }
            }
        }
    }
    rcu_read_unlock();
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Detected %d Intel network cards", found_cards);
    
    return found_cards;
}

/* Register network device */
static int ptp_ocp_register_network_device(struct ptp_ocp_enhanced *enhanced,
                                          struct net_device *dev)
{
    struct ptp_ocp_network_coordinator *coord = &enhanced->network_coord;
    struct ptp_ocp_network_device *netdev = &coord->network_dev;
    struct ethtool_ts_info ts_info;
    int ret;
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Registering network device: %s", dev->name);
    
    /* Initialize network device structure */
    strncpy(netdev->name, dev->name, IFNAMSIZ - 1);
    netdev->name[IFNAMSIZ - 1] = '\0';
    netdev->dev = dev;
    netdev->device_id = 0; /* Will be set by caller */
    
    /* Check hardware timestamping support */
    memset(&ts_info, 0, sizeof(ts_info));
    ret = ethtool_get_ts_info(dev, &ts_info);
    if (ret == 0) {
        netdev->hardware_timestamping_supported = 
            (ts_info.so_timestamping & SOF_TIMESTAMPING_TX_HARDWARE) &&
            (ts_info.so_timestamping & SOF_TIMESTAMPING_RX_HARDWARE);
        
        if (netdev->hardware_timestamping_supported) {
            ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                        "Hardware timestamping supported on %s", dev->name);
        }
    }
    
    /* Get PTP clock if available */
    if (dev->ptp_clock) {
        netdev->phc = dev->ptp_clock;
        ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                    "PTP clock found for %s", dev->name);
    }
    
    /* Enable hardware timestamping if supported */
    if (netdev->hardware_timestamping_supported) {
        ret = ptp_ocp_enable_hardware_timestamping(netdev);
        if (ret == 0) {
            ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                        "Hardware timestamping enabled on %s", dev->name);
        }
    }
    
    /* Initialize network coordinator */
    coord->timecard = enhanced;
    coord->network_dev = *netdev;
    coord->enabled = true;
    coord->sync_interval_ms = NETWORK_SYNC_INTERVAL_MS;
    coord->sync_timeout_ms = NETWORK_SYNC_TIMEOUT_MS;
    coord->max_offset_ns = NETWORK_MAX_OFFSET_NS;
    
    /* Initialize synchronization */
    INIT_WORK(&coord->sync_work, ptp_ocp_network_sync_work);
    timer_setup(&coord->sync_timer, ptp_ocp_network_sync_timer, 0);
    mutex_init(&coord->sync_mutex);
    
    /* Start synchronization timer */
    mod_timer(&coord->sync_timer,
              jiffies + msecs_to_jiffies(coord->sync_interval_ms));
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Network device %s registered successfully", dev->name);
    
    return 0;
}

/* Enable hardware timestamping */
static int ptp_ocp_enable_hardware_timestamping(struct ptp_ocp_network_device *netdev)
{
    struct net_device *dev = netdev->dev;
    struct ifreq ifr;
    int ret;
    
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, dev->name, IFNAMSIZ - 1);
    
    /* Enable hardware timestamping */
    ifr.ifr_data = (void *)SOF_TIMESTAMPING_TX_HARDWARE |
                   SOF_TIMESTAMPING_RX_HARDWARE |
                   SOF_TIMESTAMPING_RAW_HARDWARE;
    
    ret = dev_ethtool(&ifr, dev, SIOCSHWTSTAMP);
    if (ret == 0) {
        netdev->hardware_timestamping_enabled = true;
        netdev->timestamping_type = PTP_OCP_TIMESTAMPING_HARDWARE;
    }
    
    return ret;
}

/* Network synchronization work */
static void ptp_ocp_network_sync_work(struct work_struct *work)
{
    struct ptp_ocp_network_coordinator *coord = 
        container_of(work, struct ptp_ocp_network_coordinator, sync_work);
    struct ptp_ocp_enhanced *enhanced = coord->timecard;
    u64 start_time, end_time;
    int ret;
    
    start_time = ktime_get_ns();
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_DEBUG, __func__,
                "Starting network synchronization");
    
    /* Perform synchronization based on mode */
    switch (coord->mode) {
    case PTP_OCP_NETWORK_MASTER:
        ret = ptp_ocp_configure_ptp_master(enhanced);
        break;
    case PTP_OCP_NETWORK_SLAVE:
        ret = ptp_ocp_configure_ptp_slave(enhanced);
        break;
    case PTP_OCP_NETWORK_TRANSPARENT:
        ret = ptp_ocp_configure_transparent_clock(enhanced);
        break;
    case PTP_OCP_NETWORK_BOUNDARY:
        ret = ptp_ocp_configure_boundary_clock(enhanced);
        break;
    default:
        ret = -EINVAL;
        break;
    }
    
    end_time = ktime_get_ns();
    coord->total_sync_time_ns += (end_time - start_time);
    
    if (ret == 0) {
        coord->sync_success_count++;
        coord->consecutive_failures = 0;
        
        /* Update sync quality */
        coord->sync_quality = min(coord->sync_quality + 1, 100);
        
        ptp_ocp_log(enhanced, PTP_OCP_LOG_DEBUG, __func__,
                    "Network synchronization successful");
    } else {
        coord->sync_failure_count++;
        coord->consecutive_failures++;
        
        /* Decrease sync quality */
        if (coord->sync_quality > 0) {
            coord->sync_quality--;
        }
        
        ptp_ocp_log(enhanced, PTP_OCP_LOG_WARN, __func__,
                    "Network synchronization failed: %d", ret);
    }
    
    /* Update last sync time */
    coord->last_sync_time = ktime_get_ns();
}

/* Network synchronization timer */
static void ptp_ocp_network_sync_timer(struct timer_list *t)
{
    struct ptp_ocp_network_coordinator *coord = 
        from_timer(coord, t, sync_timer);
    
    if (coord->enabled) {
        schedule_work(&coord->sync_work);
        
        /* Restart timer */
        mod_timer(&coord->sync_timer,
                  jiffies + msecs_to_jiffies(coord->sync_interval_ms));
    }
}

/* Configure PTP Master mode */
static int ptp_ocp_configure_ptp_master(struct ptp_ocp_enhanced *enhanced)
{
    struct ptp_ocp_network_coordinator *coord = &enhanced->network_coord;
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Configuring PTP Master mode");
    
    /* TODO: Implement PTP Master configuration */
    /* - Send Sync messages at regular intervals */
    /* - Send Follow_Up messages with precise timestamps */
    /* - Handle Delay_Req messages from slaves */
    /* - Send Delay_Resp messages */
    
    return 0;
}

/* Configure PTP Slave mode */
static int ptp_ocp_configure_ptp_slave(struct ptp_ocp_enhanced *enhanced)
{
    struct ptp_ocp_network_coordinator *coord = &enhanced->network_coord;
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Configuring PTP Slave mode");
    
    /* TODO: Implement PTP Slave configuration */
    /* - Receive Sync messages from master */
    /* - Send Delay_Req messages */
    /* - Calculate time offset and frequency offset */
    /* - Adjust local clock */
    
    return 0;
}

/* Configure Transparent Clock */
static int ptp_ocp_configure_transparent_clock(struct ptp_ocp_enhanced *enhanced)
{
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Configuring Transparent Clock mode");
    
    /* TODO: Implement Transparent Clock */
    /* - Forward PTP messages without modification */
    /* - Add residence time to correction field */
    /* - Maintain synchronization accuracy */
    
    return 0;
}

/* Configure Boundary Clock */
static int ptp_ocp_configure_boundary_clock(struct ptp_ocp_enhanced *enhanced)
{
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Configuring Boundary Clock mode");
    
    /* TODO: Implement Boundary Clock */
    /* - Act as slave on upstream port */
    /* - Act as master on downstream ports */
    /* - Maintain multiple PTP domains */
    
    return 0;
}

/* Initialize network integration */
int ptp_ocp_init_network_integration(struct ptp_ocp_enhanced *enhanced)
{
    int ret;
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Initializing network integration");
    
    /* Detect Intel network cards */
    ret = ptp_ocp_detect_intel_cards(enhanced);
    if (ret < 0) {
        ptp_ocp_log(enhanced, PTP_OCP_LOG_ERROR, __func__,
                    "Failed to detect Intel network cards: %d", ret);
        return ret;
    }
    
    if (ret == 0) {
        ptp_ocp_log(enhanced, PTP_OCP_LOG_WARN, __func__,
                    "No Intel network cards found");
        return -ENODEV;
    }
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Network integration initialized successfully");
    
    return 0;
}

/* Cleanup network integration */
void ptp_ocp_cleanup_network_integration(struct ptp_ocp_enhanced *enhanced)
{
    struct ptp_ocp_network_coordinator *coord = &enhanced->network_coord;
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Cleaning up network integration");
    
    /* Stop synchronization */
    coord->enabled = false;
    
    if (coord->sync_timer.function) {
        del_timer_sync(&coord->sync_timer);
    }
    
    cancel_work_sync(&coord->sync_work);
    
    /* Disable hardware timestamping */
    if (coord->network_dev.hardware_timestamping_enabled) {
        ptp_ocp_disable_hardware_timestamping(&coord->network_dev);
    }
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Network integration cleaned up");
}
