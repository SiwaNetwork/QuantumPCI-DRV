/*
 * Performance module for Enhanced PTP OCP Driver
 * 
 * This module implements:
 * - Register caching for improved performance
 * - Performance monitoring and statistics
 * - Latency optimization
 * - Cache management
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/io.h>
#include <linux/pci.h>
#include <linux/ptp_clock_kernel.h>

#include "ptp_ocp_enhanced.h"

/* Invalidate cache */
static inline void ptp_ocp_invalidate_cache(struct ptp_ocp_enhanced *enhanced, u32 reg_mask)
{
	struct ptp_ocp_register_cache *cache = &enhanced->cache;

	if (reg_mask & 0x01) cache->status_valid = false;
	if (reg_mask & 0x02) cache->ctrl_valid = false;
	if (reg_mask & 0x04) cache->select_valid = false;
	if (reg_mask & 0x08) cache->time_valid = false;
}

/* Update performance statistics */
void ptp_ocp_update_performance_stats(struct ptp_ocp_enhanced *enhanced,
				      const char *operation,
				      u64 latency_ns)
{
	struct ptp_ocp_performance_stats *stats = &enhanced->perf_stats;

	if (strcmp(operation, "gettime") == 0) {
		stats->gettime_latency_ns = latency_ns;
		stats->gettime_count++;
	} else if (strcmp(operation, "settime") == 0) {
		stats->settime_latency_ns = latency_ns;
		stats->settime_count++;
	} else if (strcmp(operation, "adjtime") == 0) {
		stats->adjtime_latency_ns = latency_ns;
		stats->adjtime_count++;
	}

	/* Update cache statistics */
	stats->cache_hits = enhanced->cache.cache_hits;
	stats->cache_misses = enhanced->cache.cache_misses;
	stats->cache_hit_ratio = 
		(enhanced->cache.cache_hits * 100) / 
		(enhanced->cache.cache_hits + enhanced->cache.cache_misses);
}

/* Initialize performance features */
int ptp_ocp_init_performance(struct ptp_ocp_enhanced *enhanced)
{
	struct ptp_ocp_register_cache *cache = &enhanced->cache;
	struct ptp_ocp_performance_stats *stats = &enhanced->perf_stats;

	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Initializing performance features");

	/* Initialize cache settings */
	cache->cache_timeout_ns = enhanced->cache_timeout_ns;
	cache->cache_enabled = true;
	cache->cache_hits = 0;
	cache->cache_misses = 0;

	/* Initialize cache validity flags */
	cache->status_valid = false;
	cache->ctrl_valid = false;
	cache->select_valid = false;
	cache->time_valid = false;

	/* Initialize performance statistics */
	memset(stats, 0, sizeof(*stats));

	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Performance features initialized successfully");
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Cache timeout: %u ns", cache->cache_timeout_ns);

	return 0;
}

/* Cleanup performance features */
void ptp_ocp_cleanup_performance(struct ptp_ocp_enhanced *enhanced)
{
	struct ptp_ocp_performance_stats *stats = &enhanced->perf_stats;

	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Cleaning up performance features");

	/* Log final statistics */
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Final performance statistics:");
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "  gettime: %llu calls, avg latency: %llu ns",
		    stats->gettime_count,
		    stats->gettime_count ? stats->gettime_latency_ns : 0);
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "  settime: %llu calls, avg latency: %llu ns",
		    stats->settime_count,
		    stats->settime_count ? stats->settime_latency_ns : 0);
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "  adjtime: %llu calls, avg latency: %llu ns",
		    stats->adjtime_count,
		    stats->adjtime_count ? stats->adjtime_latency_ns : 0);
	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "  cache hit ratio: %u%%",
		    stats->cache_hit_ratio);
}

/* Reset performance statistics */
void ptp_ocp_reset_performance_stats(struct ptp_ocp_enhanced *enhanced)
{
	struct ptp_ocp_performance_stats *stats = &enhanced->perf_stats;
	struct ptp_ocp_register_cache *cache = &enhanced->cache;

	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Resetting performance statistics");

	memset(stats, 0, sizeof(*stats));
	cache->cache_hits = 0;
	cache->cache_misses = 0;

	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Performance statistics reset");
}

/* Get performance statistics */
int ptp_ocp_get_performance_stats(struct ptp_ocp_enhanced *enhanced,
				  struct ptp_ocp_performance_stats *stats)
{
	if (!enhanced || !stats)
		return -EINVAL;

	memcpy(stats, &enhanced->perf_stats, sizeof(*stats));
	return 0;
}

/* Set cache timeout */
int ptp_ocp_set_cache_timeout(struct ptp_ocp_enhanced *enhanced, u32 timeout_ns)
{
	if (timeout_ns == 0 || timeout_ns > 100000000) /* Max 100ms */
		return -EINVAL;

	enhanced->cache.cache_timeout_ns = timeout_ns;
	enhanced->cache_timeout_ns = timeout_ns;

	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Cache timeout set to %u ns", timeout_ns);

	return 0;
}

/* Enable/disable performance mode */
int ptp_ocp_set_performance_mode(struct ptp_ocp_enhanced *enhanced, bool enabled)
{
	enhanced->performance_mode = enabled;
	enhanced->cache.cache_enabled = enabled;

	ptp_ocp_log(enhanced, PTP_OCP_LOG_INFO, __func__,
		    "Performance mode %s", enabled ? "enabled" : "disabled");

	return 0;
}

/* Get cache statistics */
int ptp_ocp_get_cache_stats(struct ptp_ocp_enhanced *enhanced,
			    struct ptp_ocp_register_cache *cache)
{
	if (!enhanced || !cache)
		return -EINVAL;

	memcpy(cache, &enhanced->cache, sizeof(*cache));
	return 0;
}

/* Optimized register read with caching */
u32 ptp_ocp_read_reg_cached(struct ptp_ocp_enhanced *enhanced,
			    void __iomem *reg,
			    u32 *cache,
			    u64 *last_update,
			    bool *valid)
{
	u64 now = ktime_get_ns();

	if (*valid && (now - *last_update) < enhanced->cache.cache_timeout_ns) {
		enhanced->cache.cache_hits++;
		return *cache;
	}

	*cache = ioread32(reg);
	*last_update = now;
	*valid = true;
	enhanced->cache.cache_misses++;

	return *cache;
}

/* Optimized register write with cache invalidation */
void ptp_ocp_write_reg_cached(struct ptp_ocp_enhanced *enhanced,
			      void __iomem *reg,
			      u32 value,
			      u32 invalidate_mask)
{
	iowrite32(value, reg);
	ptp_ocp_invalidate_cache(enhanced, invalidate_mask);
}
