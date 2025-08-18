#include <linux/module.h>
#include <linux/export-internal.h>
#include <linux/compiler.h>

MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};



static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0x7851be11, "__get_user_4" },
	{ 0x0feb1e94, "usleep_range_state" },
	{ 0x6a9bd73f, "init_net" },
	{ 0xe1b587ce, "devlink_alloc_ns" },
	{ 0x78de09ff, "pci_enable_device" },
	{ 0x20ab5a86, "pci_request_selected_regions" },
	{ 0xb82edfb3, "idr_alloc" },
	{ 0xc1e6c71e, "__mutex_init" },
	{ 0xd0e49726, "device_initialize" },
	{ 0x1c43b1c0, "dev_set_name" },
	{ 0xa35bcaa0, "device_add" },
	{ 0x33ee18d0, "pci_alloc_irq_vectors" },
	{ 0x431c3b7a, "_dev_info" },
	{ 0xc5cb7f3b, "pci_set_master" },
	{ 0x864ee9fb, "ptp_clock_register" },
	{ 0x7bc55044, "ptp_clock_index" },
	{ 0x30df8ffd, "pps_lookup_dev" },
	{ 0x9f340fa0, "sysfs_create_group" },
	{ 0xe7d76335, "debugfs_create_file_full" },
	{ 0x0303191e, "pci_enable_ptm" },
	{ 0x367d8b10, "devlink_register" },
	{ 0x6bded543, "get_free_pages_noprof" },
	{ 0x02e1dca7, "free_pages" },
	{ 0x4f109577, "seq_lseek" },
	{ 0x01bbdc04, "seq_read" },
	{ 0x4bd80bc9, "single_release" },
	{ 0xd272d446, "__fentry__" },
	{ 0xd272d446, "__x86_return_thunk" },
	{ 0xc36345fa, "__sw_hweight32" },
	{ 0x7e2232fb, "ioread32" },
	{ 0xfad8f384, "iowrite32" },
	{ 0x90a48d82, "__ubsan_handle_out_of_bounds" },
	{ 0xe1e1f979, "_raw_spin_lock_irqsave" },
	{ 0x81a1a811, "_raw_spin_unlock_irqrestore" },
	{ 0xb09e712d, "i2c_verify_client" },
	{ 0x888b8f57, "strcmp" },
	{ 0x67b2ba98, "sysfs_emit_at" },
	{ 0x43a349ca, "strlen" },
	{ 0x5629a063, "strncasecmp" },
	{ 0xdd6830c7, "sysfs_emit" },
	{ 0x8e142c2e, "kstrtouint" },
	{ 0xd272d446, "__stack_chk_fail" },
	{ 0x058c185a, "jiffies" },
	{ 0x32feeafc, "mod_timer" },
	{ 0x7a6661ca, "ktime_get_real_seconds" },
	{ 0xb311a158, "ns_to_timespec64" },
	{ 0x749af2c6, "ptp_clock_event" },
	{ 0xd09b06f5, "kstrtoint" },
	{ 0x680628e7, "ktime_get_real_ts64" },
	{ 0x680628e7, "ktime_get_raw_ts64" },
	{ 0x680628e7, "ktime_get_ts64" },
	{ 0x91f966bb, "kstrtou8" },
	{ 0xf00d45ac, "kstrtou16" },
	{ 0x5a844b26, "__x86_indirect_thunk_rax" },
	{ 0x6a351207, "pci_free_irq" },
	{ 0xcb8b6ec6, "kfree" },
	{ 0x7d49d091, "debugfs_remove" },
	{ 0xcb1c6d94, "sysfs_remove_link" },
	{ 0xcbb100f2, "sysfs_remove_group" },
	{ 0x2352b148, "timer_delete_sync" },
	{ 0xb5be2d6f, "serial8250_unregister_port" },
	{ 0xf693e848, "platform_device_unregister" },
	{ 0x85acaba2, "cancel_delayed_work_sync" },
	{ 0xbce891f1, "i2c_unregister_device" },
	{ 0xadc43b86, "clk_hw_unregister_fixed_rate" },
	{ 0xd408da62, "misc_deregister" },
	{ 0x7bc55044, "ptp_clock_unregister" },
	{ 0xd0e49726, "device_unregister" },
	{ 0x5a221064, "pci_free_irq_vectors" },
	{ 0x810e9ac2, "get_device_system_crosststamp" },
	{ 0xdae35099, "ktime_get_snapshot" },
	{ 0xe8213e80, "_printk" },
	{ 0xf46d5bf3, "mutex_lock" },
	{ 0x07d50c57, "idr_remove" },
	{ 0xf46d5bf3, "mutex_unlock" },
	{ 0x662225ef, "debugfs_create_dir" },
	{ 0xc08fa087, "class_register" },
	{ 0x08c82970, "i2c_bus_type" },
	{ 0x86144b06, "bus_register_notifier" },
	{ 0x2cf3afc3, "__pci_register_driver" },
	{ 0x86144b06, "bus_unregister_notifier" },
	{ 0x7c77f2d5, "class_unregister" },
	{ 0xc13d7999, "single_open" },
	{ 0xd3981938, "seq_printf" },
	{ 0xdd6830c7, "sprintf" },
	{ 0xc1249a30, "strcpy" },
	{ 0x2d01af44, "pci_unregister_driver" },
	{ 0xe4de56b4, "__ubsan_handle_load_invalid_value" },
	{ 0xbdbdd4f3, "argv_split" },
	{ 0xd3ed45de, "strcasecmp" },
	{ 0x943d36c0, "argv_free" },
	{ 0x40a621c5, "snprintf" },
	{ 0x7ffd1a6c, "platform_device_register_full" },
	{ 0x4246784d, "pci_irq_vector" },
	{ 0x0bbd6135, "devm_clk_hw_register_clkdev" },
	{ 0xa19cae8d, "__clk_hw_register_fixed_rate" },
	{ 0x4cd64f5c, "serial8250_register_8250_port" },
	{ 0xd0e49726, "put_device" },
	{ 0x81455956, "device_find_child" },
	{ 0xd500f1f3, "devlink_priv" },
	{ 0xbd59d47a, "devlink_flash_update_status_notify" },
	{ 0x265559b4, "crc16" },
	{ 0xe8b62167, "mtd_write" },
	{ 0xf4010f1e, "mtd_erase" },
	{ 0x431c3b7a, "_dev_err" },
	{ 0xee859f78, "mtd_read" },
	{ 0x1ae87dfd, "nvmem_device_find" },
	{ 0x8d523698, "nvmem_device_read" },
	{ 0x8b945474, "nvmem_device_put" },
	{ 0xa61fd7aa, "__check_object_size" },
	{ 0x092a35a2, "_copy_from_user" },
	{ 0x8d523698, "nvmem_device_write" },
	{ 0x092a35a2, "_copy_to_user" },
	{ 0xbd03ed67, "random_kmalloc_seed" },
	{ 0xa62b1cc9, "kmalloc_caches" },
	{ 0xd1f07d8f, "__kmalloc_cache_noprof" },
	{ 0xd1071e32, "devm_ioremap" },
	{ 0x19d56671, "pci_request_irq" },
	{ 0xf74ea628, "priv_to_devlink" },
	{ 0x367d8b10, "devlink_unregister" },
	{ 0xf1cfe678, "pci_select_bars" },
	{ 0xaf1cfbd0, "pci_release_selected_regions" },
	{ 0xc5cb7f3b, "pci_disable_device" },
	{ 0x367d8b10, "devlink_free" },
	{ 0x2c20e2f6, "i2c_verify_adapter" },
	{ 0x2dd5e0da, "i2c_new_dummy_device" },
	{ 0xbb33f99f, "i2c_smbus_read_byte_data" },
	{ 0x71798f7e, "delayed_work_timer_fn" },
	{ 0x02f9bbf0, "init_timer_key" },
	{ 0xaef1f20d, "system_wq" },
	{ 0x8ce83585, "queue_delayed_work_on" },
	{ 0x5d0f6f9d, "sysfs_create_link" },
	{ 0x2ca218f5, "device_match_name" },
	{ 0x5373d78a, "kstrtobool" },
	{ 0xdba98963, "devlink_info_version_running_put" },
	{ 0xe84744e9, "devlink_info_serial_number_put" },
	{ 0xdba98963, "devlink_info_version_fixed_put" },
	{ 0x97acb853, "ktime_get" },
	{ 0x12ca6142, "ktime_get_with_offset" },
	{ 0x88fafe6b, "misc_register" },
	{ 0xbd069841, "kstrtoull" },
	{ 0x82fd7238, "__ubsan_handle_divrem_overflow" },
	{ 0x41d51c3b, "i2c_smbus_write_byte_data" },
	{ 0xd272d446, "__put_user_4" },
	{ 0xab006604, "module_layout" },
};

static const u32 ____version_ext_crcs[]
__used __section("__version_ext_crcs") = {
	0x7851be11,
	0x0feb1e94,
	0x6a9bd73f,
	0xe1b587ce,
	0x78de09ff,
	0x20ab5a86,
	0xb82edfb3,
	0xc1e6c71e,
	0xd0e49726,
	0x1c43b1c0,
	0xa35bcaa0,
	0x33ee18d0,
	0x431c3b7a,
	0xc5cb7f3b,
	0x864ee9fb,
	0x7bc55044,
	0x30df8ffd,
	0x9f340fa0,
	0xe7d76335,
	0x0303191e,
	0x367d8b10,
	0x6bded543,
	0x02e1dca7,
	0x4f109577,
	0x01bbdc04,
	0x4bd80bc9,
	0xd272d446,
	0xd272d446,
	0xc36345fa,
	0x7e2232fb,
	0xfad8f384,
	0x90a48d82,
	0xe1e1f979,
	0x81a1a811,
	0xb09e712d,
	0x888b8f57,
	0x67b2ba98,
	0x43a349ca,
	0x5629a063,
	0xdd6830c7,
	0x8e142c2e,
	0xd272d446,
	0x058c185a,
	0x32feeafc,
	0x7a6661ca,
	0xb311a158,
	0x749af2c6,
	0xd09b06f5,
	0x680628e7,
	0x680628e7,
	0x680628e7,
	0x91f966bb,
	0xf00d45ac,
	0x5a844b26,
	0x6a351207,
	0xcb8b6ec6,
	0x7d49d091,
	0xcb1c6d94,
	0xcbb100f2,
	0x2352b148,
	0xb5be2d6f,
	0xf693e848,
	0x85acaba2,
	0xbce891f1,
	0xadc43b86,
	0xd408da62,
	0x7bc55044,
	0xd0e49726,
	0x5a221064,
	0x810e9ac2,
	0xdae35099,
	0xe8213e80,
	0xf46d5bf3,
	0x07d50c57,
	0xf46d5bf3,
	0x662225ef,
	0xc08fa087,
	0x08c82970,
	0x86144b06,
	0x2cf3afc3,
	0x86144b06,
	0x7c77f2d5,
	0xc13d7999,
	0xd3981938,
	0xdd6830c7,
	0xc1249a30,
	0x2d01af44,
	0xe4de56b4,
	0xbdbdd4f3,
	0xd3ed45de,
	0x943d36c0,
	0x40a621c5,
	0x7ffd1a6c,
	0x4246784d,
	0x0bbd6135,
	0xa19cae8d,
	0x4cd64f5c,
	0xd0e49726,
	0x81455956,
	0xd500f1f3,
	0xbd59d47a,
	0x265559b4,
	0xe8b62167,
	0xf4010f1e,
	0x431c3b7a,
	0xee859f78,
	0x1ae87dfd,
	0x8d523698,
	0x8b945474,
	0xa61fd7aa,
	0x092a35a2,
	0x8d523698,
	0x092a35a2,
	0xbd03ed67,
	0xa62b1cc9,
	0xd1f07d8f,
	0xd1071e32,
	0x19d56671,
	0xf74ea628,
	0x367d8b10,
	0xf1cfe678,
	0xaf1cfbd0,
	0xc5cb7f3b,
	0x367d8b10,
	0x2c20e2f6,
	0x2dd5e0da,
	0xbb33f99f,
	0x71798f7e,
	0x02f9bbf0,
	0xaef1f20d,
	0x8ce83585,
	0x5d0f6f9d,
	0x2ca218f5,
	0x5373d78a,
	0xdba98963,
	0xe84744e9,
	0xdba98963,
	0x97acb853,
	0x12ca6142,
	0x88fafe6b,
	0xbd069841,
	0x82fd7238,
	0x41d51c3b,
	0xd272d446,
	0xab006604,
};
static const char ____version_ext_names[]
__used __section("__version_ext_names") =
	"__get_user_4\0"
	"usleep_range_state\0"
	"init_net\0"
	"devlink_alloc_ns\0"
	"pci_enable_device\0"
	"pci_request_selected_regions\0"
	"idr_alloc\0"
	"__mutex_init\0"
	"device_initialize\0"
	"dev_set_name\0"
	"device_add\0"
	"pci_alloc_irq_vectors\0"
	"_dev_info\0"
	"pci_set_master\0"
	"ptp_clock_register\0"
	"ptp_clock_index\0"
	"pps_lookup_dev\0"
	"sysfs_create_group\0"
	"debugfs_create_file_full\0"
	"pci_enable_ptm\0"
	"devlink_register\0"
	"get_free_pages_noprof\0"
	"free_pages\0"
	"seq_lseek\0"
	"seq_read\0"
	"single_release\0"
	"__fentry__\0"
	"__x86_return_thunk\0"
	"__sw_hweight32\0"
	"ioread32\0"
	"iowrite32\0"
	"__ubsan_handle_out_of_bounds\0"
	"_raw_spin_lock_irqsave\0"
	"_raw_spin_unlock_irqrestore\0"
	"i2c_verify_client\0"
	"strcmp\0"
	"sysfs_emit_at\0"
	"strlen\0"
	"strncasecmp\0"
	"sysfs_emit\0"
	"kstrtouint\0"
	"__stack_chk_fail\0"
	"jiffies\0"
	"mod_timer\0"
	"ktime_get_real_seconds\0"
	"ns_to_timespec64\0"
	"ptp_clock_event\0"
	"kstrtoint\0"
	"ktime_get_real_ts64\0"
	"ktime_get_raw_ts64\0"
	"ktime_get_ts64\0"
	"kstrtou8\0"
	"kstrtou16\0"
	"__x86_indirect_thunk_rax\0"
	"pci_free_irq\0"
	"kfree\0"
	"debugfs_remove\0"
	"sysfs_remove_link\0"
	"sysfs_remove_group\0"
	"timer_delete_sync\0"
	"serial8250_unregister_port\0"
	"platform_device_unregister\0"
	"cancel_delayed_work_sync\0"
	"i2c_unregister_device\0"
	"clk_hw_unregister_fixed_rate\0"
	"misc_deregister\0"
	"ptp_clock_unregister\0"
	"device_unregister\0"
	"pci_free_irq_vectors\0"
	"get_device_system_crosststamp\0"
	"ktime_get_snapshot\0"
	"_printk\0"
	"mutex_lock\0"
	"idr_remove\0"
	"mutex_unlock\0"
	"debugfs_create_dir\0"
	"class_register\0"
	"i2c_bus_type\0"
	"bus_register_notifier\0"
	"__pci_register_driver\0"
	"bus_unregister_notifier\0"
	"class_unregister\0"
	"single_open\0"
	"seq_printf\0"
	"sprintf\0"
	"strcpy\0"
	"pci_unregister_driver\0"
	"__ubsan_handle_load_invalid_value\0"
	"argv_split\0"
	"strcasecmp\0"
	"argv_free\0"
	"snprintf\0"
	"platform_device_register_full\0"
	"pci_irq_vector\0"
	"devm_clk_hw_register_clkdev\0"
	"__clk_hw_register_fixed_rate\0"
	"serial8250_register_8250_port\0"
	"put_device\0"
	"device_find_child\0"
	"devlink_priv\0"
	"devlink_flash_update_status_notify\0"
	"crc16\0"
	"mtd_write\0"
	"mtd_erase\0"
	"_dev_err\0"
	"mtd_read\0"
	"nvmem_device_find\0"
	"nvmem_device_read\0"
	"nvmem_device_put\0"
	"__check_object_size\0"
	"_copy_from_user\0"
	"nvmem_device_write\0"
	"_copy_to_user\0"
	"random_kmalloc_seed\0"
	"kmalloc_caches\0"
	"__kmalloc_cache_noprof\0"
	"devm_ioremap\0"
	"pci_request_irq\0"
	"priv_to_devlink\0"
	"devlink_unregister\0"
	"pci_select_bars\0"
	"pci_release_selected_regions\0"
	"pci_disable_device\0"
	"devlink_free\0"
	"i2c_verify_adapter\0"
	"i2c_new_dummy_device\0"
	"i2c_smbus_read_byte_data\0"
	"delayed_work_timer_fn\0"
	"init_timer_key\0"
	"system_wq\0"
	"queue_delayed_work_on\0"
	"sysfs_create_link\0"
	"device_match_name\0"
	"kstrtobool\0"
	"devlink_info_version_running_put\0"
	"devlink_info_serial_number_put\0"
	"devlink_info_version_fixed_put\0"
	"ktime_get\0"
	"ktime_get_with_offset\0"
	"misc_register\0"
	"kstrtoull\0"
	"__ubsan_handle_divrem_overflow\0"
	"i2c_smbus_write_byte_data\0"
	"__put_user_4\0"
	"module_layout\0"
;

MODULE_INFO(depends, "mtd");

MODULE_ALIAS("pci:v00001D9Bd00000400sv*sd*bc*sc*i*");
MODULE_ALIAS("pci:v00000B0Bd00000410sv*sd*bc*sc*i*");
MODULE_ALIAS("pci:v00001AD7d0000A000sv*sd*bc*sc*i*");

MODULE_INFO(srcversion, "ED236C6EA8B65BB6D769D73");
