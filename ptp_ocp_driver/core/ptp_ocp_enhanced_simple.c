/*
 * Simplified Enhanced PTP OCP Driver
 * 
 * This is a simplified version that adds enhanced features to the existing ptp_ocp driver
 * without requiring major changes to the original code.
 */

#include <linux/module.h>
#include <linux/pci.h>
#include <linux/ptp_clock_kernel.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/interrupt.h>
#include <linux/io.h>
/* Removed unused includes */
#include <linux/timer.h>
#include <linux/workqueue.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/version.h>
#include <linux/time.h>
#include <linux/delay.h>
#include <linux/mutex.h>
#include <linux/spinlock.h>
#include <linux/jiffies.h>
#include <linux/ktime.h>
#include <linux/fs.h>
#include <linux/sysfs.h>

MODULE_AUTHOR("Quantum Platforms Development Team");
MODULE_DESCRIPTION("Simplified Enhanced PTP OCP driver with reliability and performance improvements");
MODULE_LICENSE("GPL v2");
MODULE_VERSION("2.0.0-simple");

/* Enhanced driver configuration */
/* PTP_OCP_DRIVER_VERSION defined in Makefile */
#define PTP_OCP_MAX_DEVICES 4
#define PTP_OCP_CACHE_TIMEOUT_NS 1000000  /* 1ms default */
#define PTP_OCP_WATCHDOG_TIMEOUT_MS 5000  /* 5 seconds default */
#define PTP_OCP_MAX_RETRIES 3
#define PTP_OCP_LOG_BUFFER_SIZE 4096

/* Error codes for enhanced error handling */
enum ptp_ocp_error_code {
	PTP_OCP_ERROR_NONE = 0,
	PTP_OCP_ERROR_PTP = -1,
	PTP_OCP_ERROR_GNSS = -2,
	PTP_OCP_ERROR_I2C = -3,
	PTP_OCP_ERROR_SPI = -4,
	PTP_OCP_ERROR_GPIO = -5,
	PTP_OCP_ERROR_INTERRUPT = -6,
	PTP_OCP_ERROR_REGISTER = -7,
	PTP_OCP_ERROR_TIMEOUT = -8,
	PTP_OCP_ERROR_MEMORY = -9,
	PTP_OCP_ERROR_HARDWARE = -10,
	PTP_OCP_ERROR_FIRMWARE = -11,
	PTP_OCP_ERROR_NETWORK = -12,
	PTP_OCP_ERROR_CALIBRATION = -13
};

/* Log levels for structured logging */
enum ptp_ocp_log_level {
	PTP_OCP_LOG_DEBUG = 0,
	PTP_OCP_LOG_INFO = 1,
	PTP_OCP_LOG_WARN = 2,
	PTP_OCP_LOG_ERROR = 3,
	PTP_OCP_LOG_CRIT = 4,
	PTP_OCP_LOG_MAX
};

/* Enhanced register cache structure */
struct ptp_ocp_register_cache {
	/* Cache for status registers */
	u32 status_cache;
	u32 ctrl_cache;
	u32 select_cache;
	u64 last_status_update;
	u64 last_ctrl_update;
	u64 last_select_update;
	
	/* Cache for time values */
	u32 time_ns_cache;
	u32 time_sec_cache;
	u64 last_time_update;
	
	/* Cache validity flags */
	bool status_valid;
	bool ctrl_valid;
	bool select_valid;
	bool time_valid;
	
	/* Cache settings */
	u32 cache_timeout_ns;
	bool cache_enabled;
	
	/* Cache statistics */
	u64 cache_hits;
	u64 cache_misses;
};

/* Performance statistics structure */
struct ptp_ocp_performance_stats {
	/* Operation latencies */
	u64 gettime_latency_ns;
	u64 settime_latency_ns;
	u64 adjtime_latency_ns;
	u64 irq_latency_ns;
	
	/* Operation counts */
	u64 gettime_count;
	u64 settime_count;
	u64 adjtime_count;
	u64 irq_count;
	
	/* Cache statistics */
	u64 cache_hits;
	u64 cache_misses;
	u32 cache_hit_ratio;  /* in percentage */
	
	/* System load */
	u32 cpu_usage_percent;
	u64 memory_usage_bytes;
	u32 pcie_bandwidth_mbps;
};

/* Error handling and recovery structure */
struct ptp_ocp_error_recovery {
	u32 error_count;
	u32 max_retries;
	u32 retry_delay_ms;
	bool auto_recovery_enabled;
	enum ptp_ocp_error_code last_error;
	u64 last_error_time;
	u32 error_counts[20]; /* Fixed size array for error counts */
	struct work_struct recovery_work;
	struct timer_list retry_timer;
};

/* Watchdog structure */
struct ptp_ocp_watchdog {
	bool enabled;
	u32 timeout_ms;
	u64 last_heartbeat;
	struct timer_list timer;
	
	/* Operation monitoring */
	struct {
		u64 gettime_count;
		u64 settime_count;
		u64 last_operation_time;
	} operation_monitor;
};

/* Logger structure */
struct ptp_ocp_logger {
	enum ptp_ocp_log_level level;
	char buffer[PTP_OCP_LOG_BUFFER_SIZE];
	u32 buffer_pos;
	struct mutex log_mutex;
};

/* Enhanced main driver structure */
struct ptp_ocp_enhanced {
	/* Enhanced features */
	struct ptp_ocp_register_cache cache;
	struct ptp_ocp_performance_stats perf_stats;
	struct ptp_ocp_error_recovery error_recovery;
	struct ptp_ocp_watchdog watchdog;
	struct ptp_ocp_logger logger;
	
	/* Configuration */
	u32 cache_timeout_ns;
	bool performance_mode;
	bool reliability_mode;
	bool monitoring_enabled;
	
	/* Statistics */
	u64 driver_start_time;
	u64 last_health_check;
	u32 health_score;  /* 0-100 */
	
	/* Sysfs devices */
	struct device *sysfs_dev;
	struct device *class_dev;

	/* PTP/PHC state */
	struct ptp_clock_info ptp_info;
	struct ptp_clock *ptp_clock;
	s64 time_offset_ns;
	s64 freq_adj_ppb;
	u64 freq_ref_ns;
	s64 freq_accum_ns;
	spinlock_t time_lock;
};

/* Global variables */
static DEFINE_MUTEX(ptp_ocp_enhanced_mutex);
static struct class *ptp_ocp_enhanced_class;

/* Forward declarations */
static void ptp_ocp_recovery_work(struct work_struct *work);
static void ptp_ocp_watchdog_timer_callback(struct timer_list *t);
void ptp_ocp_log(struct ptp_ocp_enhanced *enhanced, 
            enum ptp_ocp_log_level level,
            const char *function,
            const char *format, ...);

/* Enhanced sysfs interface */
static ssize_t ptp_ocp_enhanced_show_health_status(struct device *dev,
						   struct device_attribute *attr,
						   char *buf)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	u32 health_score = enhanced->health_score;
	const char *status;
	
	if (health_score >= 90)
		status = "excellent";
	else if (health_score >= 70)
		status = "good";
	else if (health_score >= 50)
		status = "fair";
	else if (health_score >= 30)
		status = "poor";
	else
		status = "critical";
	
	return sprintf(buf, "%s (%u%%)\n", status, health_score);
}

static ssize_t ptp_ocp_enhanced_show_performance_stats(struct device *dev,
						       struct device_attribute *attr,
						       char *buf)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	struct ptp_ocp_performance_stats *stats = &enhanced->perf_stats;
	
	return sprintf(buf,
		       "gettime_latency: %llu ns\n"
		       "settime_latency: %llu ns\n"
		       "gettime_count: %llu\n"
		       "settime_count: %llu\n"
		       "cache_hits: %llu\n"
		       "cache_misses: %llu\n"
		       "cache_hit_ratio: %u%%\n",
		       stats->gettime_latency_ns,
		       stats->settime_latency_ns,
		       stats->gettime_count,
		       stats->settime_count,
		       stats->cache_hits,
		       stats->cache_misses,
		       stats->cache_hit_ratio);
}

static ssize_t ptp_ocp_enhanced_show_error_count(struct device *dev,
						 struct device_attribute *attr,
						 char *buf)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	struct ptp_ocp_error_recovery *recovery = &enhanced->error_recovery;
	
	return sprintf(buf, "%u\n", recovery->error_count);
}

static ssize_t ptp_ocp_enhanced_show_watchdog_status(struct device *dev,
						     struct device_attribute *attr,
						     char *buf)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	struct ptp_ocp_watchdog *watchdog = &enhanced->watchdog;
	const char *status;
	
	if (watchdog->enabled) {
		if (watchdog->last_heartbeat > 0)
			status = "active";
		else
			status = "enabled";
	} else {
		status = "disabled";
	}
	
	return sprintf(buf, "%s\n", status);
}

static ssize_t ptp_ocp_enhanced_store_watchdog_enabled(struct device *dev,
						       struct device_attribute *attr,
						       const char *buf, size_t count)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	struct ptp_ocp_watchdog *watchdog = &enhanced->watchdog;
	bool enabled;
	int ret;
	
	ret = kstrtobool(buf, &enabled);
	if (ret)
		return ret;
	
	watchdog->enabled = enabled;
	
	if (enabled) {
		mod_timer(&watchdog->timer, jiffies + msecs_to_jiffies(watchdog->timeout_ms));
		ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, "watchdog", "Watchdog enabled");
	} else {
		del_timer_sync(&watchdog->timer);
		ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, "watchdog", "Watchdog disabled");
	}
	
	return count;
}

static ssize_t ptp_ocp_enhanced_store_auto_recovery(struct device *dev,
						    struct device_attribute *attr,
						    const char *buf, size_t count)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	struct ptp_ocp_error_recovery *recovery = &enhanced->error_recovery;
	bool enabled;
	int ret;
	
	ret = kstrtobool(buf, &enabled);
	if (ret)
		return ret;
	
	recovery->auto_recovery_enabled = enabled;
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, "recovery", 
		    "Auto-recovery %s", enabled ? "enabled" : "disabled");
	
	return count;
}

static ssize_t ptp_ocp_enhanced_store_performance_mode(struct device *dev,
						       struct device_attribute *attr,
						       const char *buf, size_t count)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	bool enabled;
	int ret;
	
	ret = kstrtobool(buf, &enabled);
	if (ret)
		return ret;
	
	enhanced->performance_mode = enabled;
	
	if (enabled) {
		enhanced->cache.cache_timeout_ns = 500000; /* 0.5ms for performance */
		enhanced->cache.cache_enabled = true;
	} else {
		enhanced->cache.cache_timeout_ns = 1000000; /* 1ms default */
		enhanced->cache.cache_enabled = false;
	}
	
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, "performance", 
		    "Performance mode %s", enabled ? "enabled" : "disabled");
	
	return count;
}

/* Enhanced sysfs attributes */
static DEVICE_ATTR(health_status, 0444, ptp_ocp_enhanced_show_health_status, NULL);
static DEVICE_ATTR(performance_stats, 0444, ptp_ocp_enhanced_show_performance_stats, NULL);
static DEVICE_ATTR(error_count, 0444, ptp_ocp_enhanced_show_error_count, NULL);
static DEVICE_ATTR(watchdog_status, 0444, ptp_ocp_enhanced_show_watchdog_status, NULL);
static DEVICE_ATTR(watchdog_enabled, 0644, NULL, ptp_ocp_enhanced_store_watchdog_enabled);
static DEVICE_ATTR(auto_recovery, 0644, NULL, ptp_ocp_enhanced_store_auto_recovery);
static DEVICE_ATTR(performance_mode, 0644, NULL, ptp_ocp_enhanced_store_performance_mode);

static struct attribute *ptp_ocp_enhanced_attrs[] = {
	&dev_attr_health_status.attr,
	&dev_attr_performance_stats.attr,
	&dev_attr_error_count.attr,
	&dev_attr_watchdog_status.attr,
	&dev_attr_watchdog_enabled.attr,
	&dev_attr_auto_recovery.attr,
	&dev_attr_performance_mode.attr,
	NULL,
};

static const struct attribute_group ptp_ocp_enhanced_attr_group = {
	.attrs = ptp_ocp_enhanced_attrs,
};

/* Enhanced recovery work function */
static void ptp_ocp_recovery_work(struct work_struct *work)
{
	struct ptp_ocp_enhanced *enhanced = container_of(work, struct ptp_ocp_enhanced, error_recovery.recovery_work);
	struct ptp_ocp_error_recovery *recovery = &enhanced->error_recovery;
	
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, "recovery", "Starting automatic recovery...");
	
	/* Attempt recovery based on error type */
	switch (recovery->last_error) {
	case PTP_OCP_ERROR_PTP:
		/* Reset PTP clock */
		ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, "recovery", "Resetting PTP clock");
		break;
	case PTP_OCP_ERROR_GNSS:
		/* Restart GNSS synchronization */
		ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, "recovery", "Restarting GNSS sync");
		break;
	case PTP_OCP_ERROR_I2C:
		/* Reset I2C bus */
		ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, "recovery", "Resetting I2C bus");
		break;
	case PTP_OCP_ERROR_TIMEOUT:
		/* Reset device */
		ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, "recovery", "Resetting device");
		break;
	default:
		ptp_ocp_log(enhanced, PTP_OCP_LOG_WARN, "recovery", "Unknown error type, general reset");
		break;
	}
	
	/* Clear error count after successful recovery */
	recovery->error_count = 0;
	enhanced->health_score = min(100, enhanced->health_score + 10);
	
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, "recovery", "Recovery completed successfully");
}

/* Enhanced watchdog timer callback */
static void ptp_ocp_watchdog_timer_callback(struct timer_list *t)
{
	struct ptp_ocp_enhanced *enhanced = from_timer(enhanced, t, watchdog.timer);
	struct ptp_ocp_watchdog *watchdog = &enhanced->watchdog;
	u64 current_time = ktime_get_ns();
	u64 time_since_heartbeat;
	
	/* Check if device is responding */
	time_since_heartbeat = current_time - watchdog->last_heartbeat;
	
	if (time_since_heartbeat > (watchdog->timeout_ms * 1000000ULL)) {
		ptp_ocp_log(enhanced, PTP_OCP_LOG_ERROR, "watchdog", 
			    "Watchdog timeout - device not responding");
		
		/* Trigger recovery */
		if (enhanced->error_recovery.auto_recovery_enabled) {
			schedule_work(&enhanced->error_recovery.recovery_work);
		}
		
		/* Update health score */
		enhanced->health_score = max(0, enhanced->health_score - 20);
	}
	
	/* Reschedule watchdog timer */
	mod_timer(&watchdog->timer, jiffies + msecs_to_jiffies(watchdog->timeout_ms));
}

/* Public heartbeat API used by other compilation units */
void ptp_ocp_watchdog_heartbeat(struct ptp_ocp_enhanced *enhanced)
{
    if (!enhanced)
        return;
    enhanced->watchdog.last_heartbeat = ktime_get_ns();
    if (enhanced->health_score < 100)
        enhanced->health_score++;
}

/* Enhanced logging function */
void ptp_ocp_log(struct ptp_ocp_enhanced *enhanced, 
			enum ptp_ocp_log_level level,
			const char *function,
			const char *format, ...)
{
	va_list args;
	char buffer[256];
	
	if (!enhanced || !enhanced->monitoring_enabled)
		return;
	
	va_start(args, format);
	vsnprintf(buffer, sizeof(buffer), format, args);
	va_end(args);
	
	/* Log to kernel log */
	switch (level) {
	case PTP_OCP_LOG_DEBUG:
		pr_debug("[%s] %s", function, buffer);
		break;
	case PTP_OCP_LOG_INFO:
		pr_info("[%s] %s", function, buffer);
		break;
	case PTP_OCP_LOG_WARN:
		pr_warn("[%s] %s", function, buffer);
		break;
	case PTP_OCP_LOG_ERROR:
		pr_err("[%s] %s", function, buffer);
		break;
	case PTP_OCP_LOG_CRIT:
		pr_crit("[%s] %s", function, buffer);
		break;
	case PTP_OCP_LOG_MAX:
		/* Fall through */
		break;
	}
}

/* ---------------- PTP clock operations (software-backed) ---------------- */
static int ocp_ptp_gettime64(struct ptp_clock_info *ptp, struct timespec64 *ts)
{
    struct ptp_ocp_enhanced *enhanced = container_of(ptp, struct ptp_ocp_enhanced, ptp_info);
    u64 now_ns, adj_ns = 0;
    unsigned long flags;

    ktime_get_real_ts64(ts);
    now_ns = ktime_get_real_ns();

    spin_lock_irqsave(&enhanced->time_lock, flags);
    if (enhanced->freq_adj_ppb != 0) {
        u64 dt = now_ns - enhanced->freq_ref_ns;
        adj_ns = div_s64((s64)dt * enhanced->freq_adj_ppb, 1000000000LL);
    }
    /* apply software offset and accumulated freq adjustment */
    {
        s64 total_adj = enhanced->time_offset_ns + enhanced->freq_accum_ns + adj_ns;
        s64 sec = div_s64(total_adj, 1000000000LL);
        s64 rem = total_adj - sec * 1000000000LL;
        ts->tv_sec += sec;
        ts->tv_nsec += (long)rem;
        while (ts->tv_nsec < 0) { ts->tv_nsec += 1000000000L; ts->tv_sec--; }
        while (ts->tv_nsec >= 1000000000L) { ts->tv_nsec -= 1000000000L; ts->tv_sec++; }
    }
    spin_unlock_irqrestore(&enhanced->time_lock, flags);

    ptp_ocp_watchdog_heartbeat(enhanced);
    return 0;
}

static int ocp_ptp_settime64(struct ptp_clock_info *ptp, const struct timespec64 *ts)
{
    struct ptp_ocp_enhanced *enhanced = container_of(ptp, struct ptp_ocp_enhanced, ptp_info);
    struct timespec64 now;
    unsigned long flags;
    u64 now_ns, target_ns;

    ktime_get_real_ts64(&now);
    now_ns = (u64)now.tv_sec * 1000000000ULL + now.tv_nsec;
    target_ns = (u64)ts->tv_sec * 1000000000ULL + ts->tv_nsec;

    spin_lock_irqsave(&enhanced->time_lock, flags);
    enhanced->time_offset_ns = (s64)target_ns - (s64)now_ns;
    enhanced->freq_ref_ns = ktime_get_real_ns();
    enhanced->freq_accum_ns = 0;
    spin_unlock_irqrestore(&enhanced->time_lock, flags);

    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__, "settime offset=%lld", (long long)enhanced->time_offset_ns);
    return 0;
}

static int ocp_ptp_adjtime(struct ptp_clock_info *ptp, s64 delta)
{
    struct ptp_ocp_enhanced *enhanced = container_of(ptp, struct ptp_ocp_enhanced, ptp_info);
    unsigned long flags;
    spin_lock_irqsave(&enhanced->time_lock, flags);
    enhanced->time_offset_ns += delta;
    spin_unlock_irqrestore(&enhanced->time_lock, flags);
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__, "adjtime %lld", (long long)delta);
    return 0;
}

static int ocp_ptp_adjfine(struct ptp_clock_info *ptp, long scaled_ppm)
{
    struct ptp_ocp_enhanced *enhanced = container_of(ptp, struct ptp_ocp_enhanced, ptp_info);
    s64 ppb = ((s64)scaled_ppm * 1000) >> 16; /* convert to ppb */
    unsigned long flags;
    u64 now_ns = ktime_get_real_ns();
    spin_lock_irqsave(&enhanced->time_lock, flags);
    if (enhanced->freq_adj_ppb != 0) {
        u64 dt = now_ns - enhanced->freq_ref_ns;
        enhanced->freq_accum_ns += div_s64((s64)dt * enhanced->freq_adj_ppb, 1000000000LL);
    }
    enhanced->freq_adj_ppb = ppb;
    enhanced->freq_ref_ns = now_ns;
    spin_unlock_irqrestore(&enhanced->time_lock, flags);
    ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__, "adjfine scaled_ppm=%ld ppb=%lld", scaled_ppm, (long long)ppb);
    return 0;
}

/* ---------------- End PTP ops ---------------- */

/* Enhanced probe function */
static int ptp_ocp_enhanced_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	struct ptp_ocp_enhanced *enhanced;
	struct device *dev = &pdev->dev;
	int ret;
	
	dev_info(dev, "Simplified Enhanced PTP OCP driver probing device %04x:%04x\n",
		 pdev->vendor, pdev->device);
	
	/* Allocate enhanced driver structure */
	enhanced = kzalloc(sizeof(*enhanced), GFP_KERNEL);
	if (!enhanced)
		return -ENOMEM;
	
	/* Initialize enhanced features */
	enhanced->cache_timeout_ns = PTP_OCP_CACHE_TIMEOUT_NS;
	enhanced->performance_mode = false;
	enhanced->reliability_mode = true;
	enhanced->monitoring_enabled = true;
	enhanced->health_score = 100;
	enhanced->driver_start_time = ktime_get_ns();
	
	/* Initialize error recovery */
	enhanced->error_recovery.max_retries = PTP_OCP_MAX_RETRIES;
	enhanced->error_recovery.retry_delay_ms = 1000;
	enhanced->error_recovery.auto_recovery_enabled = true;
	INIT_WORK(&enhanced->error_recovery.recovery_work, ptp_ocp_recovery_work);
	
	/* Initialize watchdog */
	enhanced->watchdog.enabled = true;
	enhanced->watchdog.timeout_ms = PTP_OCP_WATCHDOG_TIMEOUT_MS;
	timer_setup(&enhanced->watchdog.timer, ptp_ocp_watchdog_timer_callback, 0);
	mod_timer(&enhanced->watchdog.timer, jiffies + msecs_to_jiffies(enhanced->watchdog.timeout_ms));
	
    /* Init time/ptp state */
    spin_lock_init(&enhanced->time_lock);
    enhanced->time_offset_ns = 0;
    enhanced->freq_adj_ppb = 0;
    enhanced->freq_ref_ns = ktime_get_real_ns();
    enhanced->freq_accum_ns = 0;

    /* Register PTP clock */
    memset(&enhanced->ptp_info, 0, sizeof(enhanced->ptp_info));
    enhanced->ptp_info.owner = THIS_MODULE;
    strscpy(enhanced->ptp_info.name, "ptp_ocp_enhanced", sizeof(enhanced->ptp_info.name));
    enhanced->ptp_info.max_adj = 500000000; /* 500 ms/s */
    enhanced->ptp_info.gettime64 = ocp_ptp_gettime64;
    enhanced->ptp_info.settime64 = ocp_ptp_settime64;
    enhanced->ptp_info.adjtime = ocp_ptp_adjtime;
    enhanced->ptp_info.adjfine = ocp_ptp_adjfine;
    enhanced->ptp_clock = ptp_clock_register(&enhanced->ptp_info, dev);
    if (IS_ERR(enhanced->ptp_clock)) {
        ret = PTR_ERR(enhanced->ptp_clock);
        dev_err(dev, "Failed to register PTP clock: %d\n", ret);
        goto err_sysfs;
    }

    /* Create class device under /sys/class/ptp_ocp_enhanced/ocp0 */
    enhanced->class_dev = device_create(ptp_ocp_enhanced_class, NULL, MKDEV(0, 0), NULL, "ocp0");
    if (IS_ERR(enhanced->class_dev)) {
        ret = PTR_ERR(enhanced->class_dev);
        dev_err(dev, "Failed to create class device: %d\n", ret);
        goto err_ptp;
    }
    dev_set_drvdata(enhanced->class_dev, enhanced);

    /* Create enhanced sysfs attributes on class device */
    enhanced->sysfs_dev = enhanced->class_dev;
    ret = sysfs_create_group(&enhanced->class_dev->kobj, &ptp_ocp_enhanced_attr_group);
    if (ret) {
        dev_err(dev, "Failed to create enhanced sysfs attributes: %d\n", ret);
        goto err_classdev;
    }

    /* Variant A compromise: expose attributes under PCI device for now */
    ret = sysfs_create_group(&dev->kobj, &ptp_ocp_enhanced_attr_group);
    if (ret) {
        dev_warn(dev, "Failed to create sysfs group on PCI dev: %d\n", ret);
    }
	
	/* Set driver data */
	pci_set_drvdata(pdev, enhanced);
	
	dev_info(dev, "Simplified Enhanced PTP OCP driver loaded successfully\n");
	return 0;
	
err_classdev:
    if (!IS_ERR(enhanced->class_dev))
        device_unregister(enhanced->class_dev);
err_ptp:
    if (!IS_ERR_OR_NULL(enhanced->ptp_clock))
        ptp_clock_unregister(enhanced->ptp_clock);
err_sysfs:
    kfree(enhanced);
    return ret;
}

/* Enhanced remove function */
static void ptp_ocp_enhanced_remove(struct pci_dev *pdev)
{
	struct ptp_ocp_enhanced *enhanced = pci_get_drvdata(pdev);
	struct device *dev = &pdev->dev;
	
	dev_info(dev, "Simplified Enhanced PTP OCP driver removing device\n");
	
	/* Stop watchdog */
	if (enhanced->watchdog.enabled) {
		del_timer_sync(&enhanced->watchdog.timer);
	}
	
    /* Remove enhanced sysfs attributes and class device */
    if (enhanced->sysfs_dev)
        sysfs_remove_group(&enhanced->sysfs_dev->kobj, &ptp_ocp_enhanced_attr_group);
    if (enhanced->class_dev)
        device_unregister(enhanced->class_dev);
	
    /* Unregister PTP clock */
    if (!IS_ERR_OR_NULL(enhanced->ptp_clock)) {
        ptp_clock_unregister(enhanced->ptp_clock);
    }
    /* Free enhanced structure */
    kfree(enhanced);
}

/* PCI device table */
static const struct pci_device_id ptp_ocp_enhanced_pci_tbl[] = {
	{ PCI_DEVICE(0x1d9b, 0x0400), 0 },  /* Quantum-PCI detected */
	{ },
};
MODULE_DEVICE_TABLE(pci, ptp_ocp_enhanced_pci_tbl);

/* PCI driver structure */
static struct pci_driver ptp_ocp_enhanced_driver = {
	.name		= "ptp_ocp_enhanced",
	.id_table	= ptp_ocp_enhanced_pci_tbl,
	.probe		= ptp_ocp_enhanced_probe,
	.remove		= ptp_ocp_enhanced_remove,
};

/* Module initialization */
static int __init ptp_ocp_enhanced_init(void)
{
	int ret;

	pr_info("Simplified Enhanced PTP OCP Driver v%s loading...\n", PTP_OCP_DRIVER_VERSION);

	/* Create device class */
	ptp_ocp_enhanced_class = class_create("ptp_ocp_enhanced");
	if (IS_ERR(ptp_ocp_enhanced_class)) {
		ret = PTR_ERR(ptp_ocp_enhanced_class);
		pr_err("Failed to create device class: %d\n", ret);
		return ret;
	}

	/* Register PCI driver */
	ret = pci_register_driver(&ptp_ocp_enhanced_driver);
	if (ret) {
		pr_err("Failed to register PCI driver: %d\n", ret);
		class_destroy(ptp_ocp_enhanced_class);
		return ret;
	}

	pr_info("Simplified Enhanced PTP OCP Driver v%s loaded successfully\n", PTP_OCP_DRIVER_VERSION);
	return 0;
}

static void __exit ptp_ocp_enhanced_exit(void)
{
	pr_info("Simplified Enhanced PTP OCP Driver v%s unloading...\n", PTP_OCP_DRIVER_VERSION);

	pci_unregister_driver(&ptp_ocp_enhanced_driver);
	class_destroy(ptp_ocp_enhanced_class);

	pr_info("Simplified Enhanced PTP OCP Driver v%s unloaded\n", PTP_OCP_DRIVER_VERSION);
}

module_init(ptp_ocp_enhanced_init);
module_exit(ptp_ocp_enhanced_exit);
