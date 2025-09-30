/*
 * Enhanced PTP OCP Driver Header
 * 
 * This header defines the enhanced driver structures and functions
 */

#ifndef _PTP_OCP_ENHANCED_H
#define _PTP_OCP_ENHANCED_H

#include <linux/module.h>
#include <linux/pci.h>
#include <linux/ptp_clock_kernel.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/interrupt.h>
#include <linux/io.h>
/* Removed unused includes: i2c, mfd, mtd, of, platform_device, spi */
#include <linux/timer.h>
#include <linux/workqueue.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/time.h>
#include <linux/delay.h>
#include <linux/mutex.h>
#include <linux/spinlock.h>
#include <linux/jiffies.h>
#include <linux/ktime.h>
#include <linux/fs.h>
#include <linux/sysfs.h>

/* Enhanced driver configuration */
#define PTP_OCP_DRIVER_VERSION "2.0.0"
#define PTP_OCP_MAX_DEVICES 4
#define PTP_OCP_CACHE_TIMEOUT_NS 1000000  /* 1ms default */
#define PTP_OCP_WATCHDOG_TIMEOUT_MS 5000  /* 5 seconds default */
#define PTP_OCP_MAX_RETRIES 3
#define PTP_OCP_LOG_BUFFER_SIZE 4096
#define PTP_OCP_ERROR_MAX_TYPES 16

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
	struct work_struct recovery_work;
	struct timer_list retry_timer;
	enum ptp_ocp_error_code last_error;
	u64 last_error_time;
	
	/* Error statistics */
    u32 error_counts[PTP_OCP_ERROR_MAX_TYPES];
	u64 total_recovery_time_ns;
	u32 successful_recoveries;
	u32 failed_recoveries;
};

/* Watchdog structure */
struct ptp_ocp_watchdog {
    struct timer_list timer;
    u32 timeout_ms;
    u64 last_heartbeat;
    bool enabled;
    bool critical_section;
    
    /* Statistics */
    u32 timeout_count;
    u32 reset_count;
    u64 last_reset_time;
    
    /* Operation monitoring */
    struct {
        u64 gettime_count;
        u64 settime_count;
        u64 last_operation_time;
        bool operation_stuck;
    } operation_monitor;
};

/* Structured logging system */
struct ptp_ocp_logger {
	enum ptp_ocp_log_level level;
	bool enable_file_logging;
	char log_file[256];
	struct mutex log_mutex;
	u64 log_rotation_size;
	u32 log_rotation_count;
	
	/* Log buffer */
	char log_buffer[PTP_OCP_LOG_BUFFER_SIZE];
	u32 log_buffer_pos;
	
	/* Log statistics */
	u64 log_entry_count;
	u32 log_level_counts[PTP_OCP_LOG_MAX];
};

/* Network coordination: planned for future phases */

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
	
	/* Sysfs device (for attribute group binding) */
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

/* Function declarations */

/* Enhanced logging and watchdog functions (implemented in core) */
void ptp_ocp_log(struct ptp_ocp_enhanced *enhanced, 
		   enum ptp_ocp_log_level level,
		   const char *function,
		   const char *format, ...);
void ptp_ocp_watchdog_heartbeat(struct ptp_ocp_enhanced *enhanced);

/* Note: reliability.c, performance.c, monitoring.c modules are not linked yet.
 * Functions are self-contained in ptp_ocp_enhanced_simple.c for now. */

#endif /* _PTP_OCP_ENHANCED_H */
