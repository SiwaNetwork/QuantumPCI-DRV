/*
 * Monitoring module for Enhanced PTP OCP Driver
 * 
 * This module implements:
 * - Health monitoring
 * - Performance metrics collection
 * - System resource monitoring
 * - Alert generation
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/io.h>
#include <linux/pci.h>
#include <linux/ptp_clock_kernel.h>
#include <linux/sysfs.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/debugfs.h>

#include "ptp_ocp_enhanced.h"

/* Health monitoring */
static void ptp_ocp_update_health_score(struct ptp_ocp_enhanced *enhanced)
{
	u32 health_score = 100;
	struct ptp_ocp_error_recovery *recovery = &enhanced->error_recovery;
	struct ptp_ocp_performance_stats *stats = &enhanced->perf_stats;

	/* Reduce health score based on errors */
	if (recovery->error_count > 0) {
		health_score -= min(recovery->error_count * 10, 50);
	}

	/* Reduce health score based on performance */
	if (stats->gettime_latency_ns > 10000) { /* > 10us */
		health_score -= 10;
	}

	/* Reduce health score based on cache hit ratio */
	if (stats->cache_hit_ratio < 80) {
		health_score -= 5;
	}

	/* Reduce health score based on watchdog timeouts */
	if (enhanced->watchdog.timeout_count > 0) {
		health_score -= enhanced->watchdog.timeout_count * 15;
	}

	enhanced->health_score = max(health_score, 0);
}

/* System resource monitoring */
static void ptp_ocp_update_system_metrics(struct ptp_ocp_enhanced *enhanced)
{
	struct ptp_ocp_performance_stats *stats = &enhanced->perf_stats;

	/* Update CPU usage (simplified) */
	stats->cpu_usage_percent = 0; /* TODO: Implement CPU monitoring */

	/* Update memory usage */
	stats->memory_usage_bytes = sizeof(*enhanced);

	/* Update PCIe bandwidth (simplified) */
	stats->pcie_bandwidth_mbps = 0; /* TODO: Implement PCIe monitoring */
}

/* Initialize monitoring features */
int ptp_ocp_init_monitoring(struct ptp_ocp_enhanced *enhanced)
{
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Initializing monitoring features");

	/* Initialize health monitoring */
	enhanced->health_score = 100;
	enhanced->last_health_check = ktime_get_ns();

	/* Initialize system metrics */
	ptp_ocp_update_system_metrics(enhanced);

	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Monitoring features initialized successfully");

	return 0;
}

/* Cleanup monitoring features */
void ptp_ocp_cleanup_monitoring(struct ptp_ocp_enhanced *enhanced)
{
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Cleaning up monitoring features");

	/* Final health check */
	ptp_ocp_update_health_score(enhanced);
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Final health score: %u", enhanced->health_score);
}

/* Update monitoring data */
void ptp_ocp_update_monitoring(struct ptp_ocp_enhanced *enhanced)
{
	u64 now = ktime_get_ns();

	/* Update health score */
	ptp_ocp_update_health_score(enhanced);

	/* Update system metrics */
	ptp_ocp_update_system_metrics(enhanced);

	/* Update last health check time */
	enhanced->last_health_check = now;
}

/* Sysfs show functions */
static ssize_t ptp_ocp_show_performance_stats(struct device *dev,
					      struct device_attribute *attr,
					      char *buf)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	struct ptp_ocp_performance_stats *stats = &enhanced->perf_stats;
	int len = 0;

	len += sprintf(buf + len, "Performance Statistics:\n");
	len += sprintf(buf + len, "  gettime: %llu calls, latency: %llu ns\n",
		       stats->gettime_count, stats->gettime_latency_ns);
	len += sprintf(buf + len, "  settime: %llu calls, latency: %llu ns\n",
		       stats->settime_count, stats->settime_latency_ns);
	len += sprintf(buf + len, "  adjtime: %llu calls, latency: %llu ns\n",
		       stats->adjtime_count, stats->adjtime_latency_ns);
	len += sprintf(buf + len, "  cache hits: %llu, misses: %llu, ratio: %u%%\n",
		       stats->cache_hits, stats->cache_misses, stats->cache_hit_ratio);
	len += sprintf(buf + len, "  CPU usage: %u%%, Memory: %llu bytes\n",
		       stats->cpu_usage_percent, stats->memory_usage_bytes);

	return len;
}

static ssize_t ptp_ocp_show_cache_stats(struct device *dev,
					struct device_attribute *attr,
					char *buf)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	struct ptp_ocp_register_cache *cache = &enhanced->cache;
	int len = 0;

	len += sprintf(buf + len, "Cache Statistics:\n");
	len += sprintf(buf + len, "  timeout: %u ns\n", cache->cache_timeout_ns);
	len += sprintf(buf + len, "  enabled: %s\n", cache->cache_enabled ? "yes" : "no");
	len += sprintf(buf + len, "  hits: %llu\n", cache->cache_hits);
	len += sprintf(buf + len, "  misses: %llu\n", cache->cache_misses);
    len += sprintf(buf + len, "  hit ratio: %llu%%\n",
                   (cache->cache_hits * 100ULL) / (cache->cache_hits + cache->cache_misses));

	return len;
}

static ssize_t ptp_ocp_store_cache_timeout(struct device *dev,
					   struct device_attribute *attr,
					   const char *buf, size_t count)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	u32 timeout_ns;
	int ret;

	ret = kstrtou32(buf, 10, &timeout_ns);
	if (ret)
		return ret;

	/* Directly set cache timeout (performance.c not linked) */
	enhanced->cache.cache_timeout_ns = timeout_ns;
	enhanced->cache_timeout_ns = timeout_ns;

	return count;
}

static ssize_t ptp_ocp_show_error_count(struct device *dev,
					struct device_attribute *attr,
					char *buf)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	struct ptp_ocp_error_recovery *recovery = &enhanced->error_recovery;
	int len = 0;

	len += sprintf(buf + len, "Error Statistics:\n");
	len += sprintf(buf + len, "  total errors: %u\n", recovery->error_count);
	len += sprintf(buf + len, "  max retries: %u\n", recovery->max_retries);
	len += sprintf(buf + len, "  auto recovery: %s\n",
		       recovery->auto_recovery_enabled ? "enabled" : "disabled");
	len += sprintf(buf + len, "  successful recoveries: %u\n", recovery->successful_recoveries);
	len += sprintf(buf + len, "  failed recoveries: %u\n", recovery->failed_recoveries);
	len += sprintf(buf + len, "  last error: %d\n", recovery->last_error);

	return len;
}

static ssize_t ptp_ocp_show_watchdog_status(struct device *dev,
					    struct device_attribute *attr,
					    char *buf)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	struct ptp_ocp_watchdog *watchdog = &enhanced->watchdog;
	int len = 0;

	len += sprintf(buf + len, "Watchdog Status:\n");
	len += sprintf(buf + len, "  enabled: %s\n", watchdog->enabled ? "yes" : "no");
	len += sprintf(buf + len, "  timeout: %u ms\n", watchdog->timeout_ms);
    len += sprintf(buf + len, "  last heartbeat: %u ms ago\n",
                   jiffies_to_msecs(jiffies) - (u32)watchdog->last_heartbeat);
	len += sprintf(buf + len, "  timeout count: %u\n", watchdog->timeout_count);
	len += sprintf(buf + len, "  reset count: %u\n", watchdog->reset_count);

	return len;
}

static ssize_t ptp_ocp_store_watchdog_enabled(struct device *dev,
					      struct device_attribute *attr,
					      const char *buf, size_t count)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	struct ptp_ocp_watchdog *watchdog = &enhanced->watchdog;
	bool enabled;

	if (strncmp(buf, "enabled", 7) == 0) {
		enabled = true;
	} else if (strncmp(buf, "disabled", 8) == 0) {
		enabled = false;
	} else {
		return -EINVAL;
	}

	watchdog->enabled = enabled;

	if (enabled) {
		ptp_ocp_watchdog_heartbeat(enhanced);
        mod_timer(&watchdog->timer,
			  jiffies + msecs_to_jiffies(watchdog->timeout_ms));
	} else {
        del_timer_sync(&watchdog->timer);
	}

	return count;
}

static ssize_t ptp_ocp_show_health_status(struct device *dev,
					  struct device_attribute *attr,
					  char *buf)
{
	struct ptp_ocp_enhanced *enhanced = dev_get_drvdata(dev);
	int len = 0;

	/* Update health score */
	ptp_ocp_update_health_score(enhanced);

	len += sprintf(buf + len, "Health Status:\n");
	len += sprintf(buf + len, "  health score: %u/100\n", enhanced->health_score);
	len += sprintf(buf + len, "  last check: %llu ns ago\n",
		       ktime_get_ns() - enhanced->last_health_check);
	len += sprintf(buf + len, "  driver uptime: %llu ns\n",
		       ktime_get_ns() - enhanced->driver_start_time);

	return len;
}

/* Sysfs attribute definitions */
static DEVICE_ATTR(performance_stats, 0444, ptp_ocp_show_performance_stats, NULL);
static DEVICE_ATTR(cache_stats, 0444, ptp_ocp_show_cache_stats, NULL);
static DEVICE_ATTR(cache_timeout, 0644, NULL, ptp_ocp_store_cache_timeout);
static DEVICE_ATTR(error_count, 0444, ptp_ocp_show_error_count, NULL);
static DEVICE_ATTR(watchdog_status, 0444, ptp_ocp_show_watchdog_status, NULL);
static DEVICE_ATTR(watchdog_enabled, 0644, NULL, ptp_ocp_store_watchdog_enabled);
static DEVICE_ATTR(health_status, 0444, ptp_ocp_show_health_status, NULL);

/* Sysfs attribute group */
static struct attribute *ptp_ocp_enhanced_attrs[] = {
	&dev_attr_performance_stats.attr,
	&dev_attr_cache_stats.attr,
	&dev_attr_cache_timeout.attr,
	&dev_attr_error_count.attr,
	&dev_attr_watchdog_status.attr,
	&dev_attr_watchdog_enabled.attr,
	&dev_attr_health_status.attr,
	NULL,
};

static const struct attribute_group ptp_ocp_enhanced_group = {
	.attrs = ptp_ocp_enhanced_attrs,
};

/* Create sysfs interface */
int ptp_ocp_create_sysfs(struct ptp_ocp_enhanced *enhanced)
{
    struct device *dev = enhanced->sysfs_dev;
	int ret;

	ret = sysfs_create_group(&dev->kobj, &ptp_ocp_enhanced_group);
	if (ret) {
		ptp_ocp_log(enhanced, PTP_OCP_LOG_ERROR, __func__,
			    "Failed to create sysfs group: %d", ret);
		return ret;
	}

	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Sysfs interface created successfully");

	return 0;
}

/* Remove sysfs interface */
void ptp_ocp_remove_sysfs(struct ptp_ocp_enhanced *enhanced)
{
    struct device *dev = enhanced->sysfs_dev;

	sysfs_remove_group(&dev->kobj, &ptp_ocp_enhanced_group);

	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Sysfs interface removed");
}
