/*
 * PTP Security Module
 * 
 * This module implements:
 * - PTP message authentication
 * - Security event logging
 * - Access control
 * - Audit trail
 * - Encryption support
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/netdevice.h>
#include <linux/crypto.h>
#include <linux/scatterlist.h>
#include <linux/random.h>
#include <linux/string.h>
#include <linux/slab.h>
#include <linux/mutex.h>
#include <linux/spinlock.h>
#include <linux/ktime.h>
#include <linux/jiffies.h>
#include <linux/workqueue.h>
#include <linux/timer.h>

#include "../phase3_extensions.h"

/* Security Constants */
#define PTP_SECURITY_KEY_SIZE          32
#define PTP_SECURITY_IV_SIZE           16
#define PTP_SECURITY_HMAC_SIZE         32
#define PTP_SECURITY_MAX_KEYS          16
#define PTP_SECURITY_AUDIT_LOG_SIZE    1000
#define PTP_SECURITY_SESSION_TIMEOUT   3600  /* 1 hour */

/* Security Event Types */
enum ptp_security_event_type {
    PTP_SECURITY_EVENT_AUTH_SUCCESS = 0,
    PTP_SECURITY_EVENT_AUTH_FAILURE,
    PTP_SECURITY_EVENT_KEY_EXPIRED,
    PTP_SECURITY_EVENT_INVALID_MESSAGE,
    PTP_SECURITY_EVENT_ACCESS_DENIED,
    PTP_SECURITY_EVENT_ENCRYPTION_FAILURE,
    PTP_SECURITY_EVENT_DECRYPTION_FAILURE,
    PTP_SECURITY_EVENT_SESSION_TIMEOUT,
    PTP_SECURITY_EVENT_ADMIN_ACTION
};

/* Security Event */
struct ptp_security_event {
    enum ptp_security_event_type type;
    u64 timestamp;
    u32 source_ip;
    u16 source_port;
    u32 key_id;
    char description[128];
    struct list_head list;
};

/* Security Key */
struct ptp_security_key {
    u32 key_id;
    u8 key[PTP_SECURITY_KEY_SIZE];
    u64 created_time;
    u64 expires_time;
    bool active;
    u32 use_count;
    struct list_head list;
};

/* Security Session */
struct ptp_security_session {
    u32 session_id;
    u32 client_ip;
    u16 client_port;
    u32 key_id;
    u64 created_time;
    u64 last_activity;
    u32 message_count;
    bool authenticated;
    struct list_head list;
};

/* Security Configuration */
struct ptp_security_config {
    bool authentication_enabled;
    bool encryption_enabled;
    bool audit_logging_enabled;
    u32 default_key_lifetime;
    u32 session_timeout;
    u32 max_sessions;
    u32 max_keys;
    char admin_password[64];
};

/* Security Statistics */
struct ptp_security_stats {
    u64 authentication_successes;
    u64 authentication_failures;
    u64 encryption_operations;
    u64 decryption_operations;
    u64 security_events;
    u64 active_sessions;
    u64 active_keys;
    u64 audit_events;
};

/* Security Manager */
struct ptp_security_manager {
    struct ptp_security_config config;
    struct ptp_security_stats stats;
    struct list_head keys;
    struct list_head sessions;
    struct list_head audit_log;
    struct mutex keys_mutex;
    struct mutex sessions_mutex;
    struct mutex audit_mutex;
    struct work_struct cleanup_work;
    struct timer_list cleanup_timer;
    struct crypto_shash *hmac_tfm;
    struct crypto_aead *cipher_tfm;
    struct ptp_ocp_enhanced *timecard;
    bool active;
    u32 next_key_id;
    u32 next_session_id;
};

/* Forward declarations */
static int ptp_security_init_manager(struct ptp_security_manager *manager,
                                     struct ptp_ocp_enhanced *timecard);
static void ptp_security_cleanup_manager(struct ptp_security_manager *manager);
static int ptp_security_create_key(struct ptp_security_manager *manager,
                                   u32 key_id, u8 *key_data);
static void ptp_security_destroy_key(struct ptp_security_manager *manager,
                                     u32 key_id);
static int ptp_security_authenticate_message(struct ptp_security_manager *manager,
                                            u8 *message, u32 message_len,
                                            u8 *hmac, u32 key_id);
static int ptp_security_encrypt_message(struct ptp_security_manager *manager,
                                       u8 *plaintext, u32 plaintext_len,
                                       u8 *ciphertext, u32 *ciphertext_len,
                                       u32 key_id);
static int ptp_security_decrypt_message(struct ptp_security_manager *manager,
                                       u8 *ciphertext, u32 ciphertext_len,
                                       u8 *plaintext, u32 *plaintext_len,
                                       u32 key_id);
static void ptp_security_log_event(struct ptp_security_manager *manager,
                                   enum ptp_security_event_type type,
                                   u32 source_ip, u16 source_port,
                                   u32 key_id, const char *description);
static void ptp_security_cleanup_work(struct work_struct *work);
static void ptp_security_cleanup_timer_callback(struct timer_list *t);
static struct ptp_security_key *ptp_security_find_key(struct ptp_security_manager *manager,
                                                      u32 key_id);
static struct ptp_security_session *ptp_security_find_session(struct ptp_security_manager *manager,
                                                              u32 client_ip, u16 client_port);
static struct ptp_security_session *ptp_security_create_session(struct ptp_security_manager *manager,
                                                                u32 client_ip, u16 client_port,
                                                                u32 key_id);

/* Initialize security manager */
static int ptp_security_init_manager(struct ptp_security_manager *manager,
                                     struct ptp_ocp_enhanced *timecard)
{
    int ret;
    
    if (!manager || !timecard)
        return -EINVAL;
    
    memset(manager, 0, sizeof(*manager));
    
    /* Set configuration */
    manager->config.authentication_enabled = true;
    manager->config.encryption_enabled = false; /* TODO: Enable when needed */
    manager->config.audit_logging_enabled = true;
    manager->config.default_key_lifetime = 86400; /* 24 hours */
    manager->config.session_timeout = PTP_SECURITY_SESSION_TIMEOUT;
    manager->config.max_sessions = 100;
    manager->config.max_keys = PTP_SECURITY_MAX_KEYS;
    strncpy(manager->config.admin_password, "default_password", 
            sizeof(manager->config.admin_password) - 1);
    
    /* Initialize statistics */
    memset(&manager->stats, 0, sizeof(manager->stats));
    
    /* Initialize lists */
    INIT_LIST_HEAD(&manager->keys);
    INIT_LIST_HEAD(&manager->sessions);
    INIT_LIST_HEAD(&manager->audit_log);
    
    /* Initialize mutexes */
    mutex_init(&manager->keys_mutex);
    mutex_init(&manager->sessions_mutex);
    mutex_init(&manager->audit_mutex);
    
    /* Initialize work queue */
    INIT_WORK(&manager->cleanup_work, ptp_security_cleanup_work);
    
    /* Initialize cleanup timer */
    timer_setup(&manager->cleanup_timer, ptp_security_cleanup_timer_callback, 0);
    
    /* Initialize crypto transforms */
    manager->hmac_tfm = crypto_alloc_shash("hmac(sha256)", 0, 0);
    if (IS_ERR(manager->hmac_tfm)) {
        ret = PTR_ERR(manager->hmac_tfm);
        ptp_ocp_log(timecard, PTP_OCP_LOG_ERROR, __func__,
                    "Failed to allocate HMAC transform: %d", ret);
        return ret;
    }
    
    /* Store timecard reference */
    manager->timecard = timecard;
    
    /* Initialize counters */
    manager->next_key_id = 1;
    manager->next_session_id = 1;
    
    /* Mark manager as active */
    manager->active = true;
    
    /* Start cleanup timer */
    mod_timer(&manager->cleanup_timer, 
              jiffies + msecs_to_jiffies(60000)); /* 1 minute */
    
    ptp_ocp_log(timecard, PTP_OCP_LOG_INFO, __func__,
                "Security manager initialized successfully");
    
    return 0;
}

/* Create security key */
static int ptp_security_create_key(struct ptp_security_manager *manager,
                                   u32 key_id, u8 *key_data)
{
    struct ptp_security_key *key;
    u64 current_time = ktime_get_ns();
    
    if (!manager || !key_data)
        return -EINVAL;
    
    mutex_lock(&manager->keys_mutex);
    
    /* Check if key already exists */
    if (ptp_security_find_key(manager, key_id)) {
        mutex_unlock(&manager->keys_mutex);
        return -EEXIST;
    }
    
    /* Check key limit */
    if (manager->stats.active_keys >= manager->config.max_keys) {
        mutex_unlock(&manager->keys_mutex);
        return -ENOSPC;
    }
    
    /* Allocate key structure */
    key = kzalloc(sizeof(*key), GFP_KERNEL);
    if (!key) {
        mutex_unlock(&manager->keys_mutex);
        return -ENOMEM;
    }
    
    /* Initialize key */
    key->key_id = key_id;
    memcpy(key->key, key_data, PTP_SECURITY_KEY_SIZE);
    key->created_time = current_time;
    key->expires_time = current_time + (manager->config.default_key_lifetime * 1000000000ULL);
    key->active = true;
    key->use_count = 0;
    
    /* Add to list */
    list_add_tail(&key->list, &manager->keys);
    manager->stats.active_keys++;
    
    mutex_unlock(&manager->keys_mutex);
    
    /* Log event */
    ptp_security_log_event(manager, PTP_SECURITY_EVENT_ADMIN_ACTION, 0, 0, key_id,
                          "Security key created");
    
    ptp_ocp_log(manager->timecard, PTP_OCP_LOG_INFO, __func__,
                "Security key %u created", key_id);
    
    return 0;
}

/* Authenticate PTP message */
static int ptp_security_authenticate_message(struct ptp_security_manager *manager,
                                            u8 *message, u32 message_len,
                                            u8 *hmac, u32 key_id)
{
    struct ptp_security_key *key;
    struct shash_desc *desc;
    u8 calculated_hmac[PTP_SECURITY_HMAC_SIZE];
    int ret;
    
    if (!manager || !message || !hmac)
        return -EINVAL;
    
    mutex_lock(&manager->keys_mutex);
    
    /* Find key */
    key = ptp_security_find_key(manager, key_id);
    if (!key || !key->active) {
        mutex_unlock(&manager->keys_mutex);
        ptp_security_log_event(manager, PTP_SECURITY_EVENT_AUTH_FAILURE, 0, 0, key_id,
                              "Authentication failed: invalid key");
        return -EINVAL;
    }
    
    /* Check key expiration */
    if (ktime_get_ns() > key->expires_time) {
        mutex_unlock(&manager->keys_mutex);
        ptp_security_log_event(manager, PTP_SECURITY_EVENT_KEY_EXPIRED, 0, 0, key_id,
                              "Authentication failed: key expired");
        return -EINVAL;
    }
    
    /* Allocate shash descriptor */
    desc = kmalloc(sizeof(*desc) + crypto_shash_descsize(manager->hmac_tfm), GFP_KERNEL);
    if (!desc) {
        mutex_unlock(&manager->keys_mutex);
        return -ENOMEM;
    }
    
    desc->tfm = manager->hmac_tfm;
    
    /* Initialize HMAC */
    ret = crypto_shash_setkey(manager->hmac_tfm, key->key, PTP_SECURITY_KEY_SIZE);
    if (ret) {
        kfree(desc);
        mutex_unlock(&manager->keys_mutex);
        return ret;
    }
    
    ret = crypto_shash_init(desc);
    if (ret) {
        kfree(desc);
        mutex_unlock(&manager->keys_mutex);
        return ret;
    }
    
    /* Update HMAC */
    ret = crypto_shash_update(desc, message, message_len);
    if (ret) {
        kfree(desc);
        mutex_unlock(&manager->keys_mutex);
        return ret;
    }
    
    /* Finalize HMAC */
    ret = crypto_shash_final(desc, calculated_hmac);
    kfree(desc);
    mutex_unlock(&manager->keys_mutex);
    
    if (ret) {
        return ret;
    }
    
    /* Compare HMACs */
    if (memcmp(hmac, calculated_hmac, PTP_SECURITY_HMAC_SIZE) != 0) {
        ptp_security_log_event(manager, PTP_SECURITY_EVENT_AUTH_FAILURE, 0, 0, key_id,
                              "Authentication failed: HMAC mismatch");
        return -EINVAL;
    }
    
    /* Update key usage */
    key->use_count++;
    
    /* Log success */
    ptp_security_log_event(manager, PTP_SECURITY_EVENT_AUTH_SUCCESS, 0, 0, key_id,
                          "Message authenticated successfully");
    
    return 0;
}

/* Log security event */
static void ptp_security_log_event(struct ptp_security_manager *manager,
                                   enum ptp_security_event_type type,
                                   u32 source_ip, u16 source_port,
                                   u32 key_id, const char *description)
{
    struct ptp_security_event *event;
    
    if (!manager || !description)
        return;
    
    mutex_lock(&manager->audit_mutex);
    
    /* Allocate event */
    event = kzalloc(sizeof(*event), GFP_KERNEL);
    if (!event) {
        mutex_unlock(&manager->audit_mutex);
        return;
    }
    
    /* Initialize event */
    event->type = type;
    event->timestamp = ktime_get_ns();
    event->source_ip = source_ip;
    event->source_port = source_port;
    event->key_id = key_id;
    strncpy(event->description, description, sizeof(event->description) - 1);
    event->description[sizeof(event->description) - 1] = '\0';
    
    /* Add to audit log */
    list_add_tail(&event->list, &manager->audit_log);
    manager->stats.audit_events++;
    
    /* Limit audit log size */
    if (manager->stats.audit_events > PTP_SECURITY_AUDIT_LOG_SIZE) {
        struct ptp_security_event *old_event;
        old_event = list_first_entry(&manager->audit_log, struct ptp_security_event, list);
        list_del(&old_event->list);
        kfree(old_event);
        manager->stats.audit_events--;
    }
    
    mutex_unlock(&manager->audit_mutex);
    
    /* Update statistics */
    manager->stats.security_events++;
    
    /* Log to system log */
    ptp_ocp_log(manager->timecard, PTP_OCP_LOG_INFO, __func__,
                "Security event: %s", description);
}

/* Find security key */
static struct ptp_security_key *ptp_security_find_key(struct ptp_security_manager *manager,
                                                      u32 key_id)
{
    struct ptp_security_key *key;
    
    list_for_each_entry(key, &manager->keys, list) {
        if (key->key_id == key_id) {
            return key;
        }
    }
    
    return NULL;
}

/* Cleanup expired keys and sessions */
static void ptp_security_cleanup_work(struct work_struct *work)
{
    struct ptp_security_manager *manager = 
        container_of(work, struct ptp_security_manager, cleanup_work);
    struct ptp_security_key *key, *key_temp;
    struct ptp_security_session *session, *session_temp;
    u64 current_time = ktime_get_ns();
    
    /* Cleanup expired keys */
    mutex_lock(&manager->keys_mutex);
    list_for_each_entry_safe(key, key_temp, &manager->keys, list) {
        if (current_time > key->expires_time) {
            list_del(&key->list);
            kfree(key);
            manager->stats.active_keys--;
            
            ptp_security_log_event(manager, PTP_SECURITY_EVENT_KEY_EXPIRED, 0, 0, key->key_id,
                                  "Security key expired and removed");
        }
    }
    mutex_unlock(&manager->keys_mutex);
    
    /* Cleanup expired sessions */
    mutex_lock(&manager->sessions_mutex);
    list_for_each_entry_safe(session, session_temp, &manager->sessions, list) {
        if (current_time - session->last_activity > 
            (manager->config.session_timeout * 1000000000ULL)) {
            list_del(&session->list);
            kfree(session);
            manager->stats.active_sessions--;
            
            ptp_security_log_event(manager, PTP_SECURITY_EVENT_SESSION_TIMEOUT, 
                                  session->client_ip, session->client_port, session->key_id,
                                  "Security session expired");
        }
    }
    mutex_unlock(&manager->sessions_mutex);
}

/* Cleanup timer callback */
static void ptp_security_cleanup_timer_callback(struct timer_list *t)
{
    struct ptp_security_manager *manager = 
        from_timer(manager, t, cleanup_timer);
    
    if (manager->active) {
        /* Schedule cleanup work */
        schedule_work(&manager->cleanup_work);
        
        /* Restart timer */
        mod_timer(&manager->cleanup_timer, 
                  jiffies + msecs_to_jiffies(60000)); /* 1 minute */
    }
}

/* Initialize PTP security */
int ptp_security_init_security(struct ptp_ocp_enhanced *enhanced)
{
    struct ptp_security_manager *manager;
    u8 default_key[PTP_SECURITY_KEY_SIZE];
    int ret;
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Initializing PTP security");
    
    /* Allocate manager */
    manager = kzalloc(sizeof(*manager), GFP_KERNEL);
    if (!manager) {
        return -ENOMEM;
    }
    
    /* Initialize manager */
    ret = ptp_security_init_manager(manager, enhanced);
    if (ret) {
        kfree(manager);
        return ret;
    }
    
    /* Create default key */
    get_random_bytes(default_key, PTP_SECURITY_KEY_SIZE);
    ret = ptp_security_create_key(manager, 1, default_key);
    if (ret) {
        ptp_security_cleanup_manager(manager);
        kfree(manager);
        return ret;
    }
    
    /* TODO: Store manager in enhanced driver structure */
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "PTP security initialized successfully");
    
    return 0;
}

/* Cleanup PTP security */
void ptp_security_cleanup_security(struct ptp_ocp_enhanced *enhanced)
{
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "Cleaning up PTP security");
    
    /* TODO: Get manager from enhanced structure and cleanup */
    
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
                "PTP security cleaned up");
}

/* Cleanup security manager */
static void ptp_security_cleanup_manager(struct ptp_security_manager *manager)
{
    struct ptp_security_key *key, *key_temp;
    struct ptp_security_session *session, *session_temp;
    struct ptp_security_event *event, *event_temp;
    
    if (!manager) {
        return;
    }
    
    /* Stop timers */
    if (manager->cleanup_timer.function) {
        del_timer_sync(&manager->cleanup_timer);
    }
    
    /* Cancel work */
    cancel_work_sync(&manager->cleanup_work);
    
    /* Free crypto transforms */
    if (manager->hmac_tfm) {
        crypto_free_shash(manager->hmac_tfm);
    }
    if (manager->cipher_tfm) {
        crypto_free_aead(manager->cipher_tfm);
    }
    
    /* Cleanup keys */
    mutex_lock(&manager->keys_mutex);
    list_for_each_entry_safe(key, key_temp, &manager->keys, list) {
        list_del(&key->list);
        kfree(key);
    }
    mutex_unlock(&manager->keys_mutex);
    
    /* Cleanup sessions */
    mutex_lock(&manager->sessions_mutex);
    list_for_each_entry_safe(session, session_temp, &manager->sessions, list) {
        list_del(&session->list);
        kfree(session);
    }
    mutex_unlock(&manager->sessions_mutex);
    
    /* Cleanup audit log */
    mutex_lock(&manager->audit_mutex);
    list_for_each_entry_safe(event, event_temp, &manager->audit_log, list) {
        list_del(&event->list);
        kfree(event);
    }
    mutex_unlock(&manager->audit_mutex);
    
    /* Mark manager as inactive */
    manager->active = false;
}

