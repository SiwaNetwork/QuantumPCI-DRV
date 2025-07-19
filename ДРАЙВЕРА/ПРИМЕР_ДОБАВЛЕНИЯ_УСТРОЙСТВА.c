/*
 * Пример добавления нового устройства TimeCard в драйвер ptp_ocp.c
 * 
 * Это пример кода, который нужно добавить в соответствующие места файла ptp_ocp.c
 * для поддержки нового устройства "Example TimeCard" с PCI ID 0x1234:0x5678
 */

/* ========== ШАГ 1: Добавить после существующих определений vendor/device ID ========== */
/* Около строки 70 в ptp_ocp.c */

#define PCI_VENDOR_ID_EXAMPLE 0x1234

#ifndef PCI_DEVICE_ID_EXAMPLE_TIMECARD
#define PCI_DEVICE_ID_EXAMPLE_TIMECARD 0x5678
#endif

/* ========== ШАГ 2: Создать таблицу ресурсов для устройства ========== */
/* Добавить после существующих таблиц ресурсов, например после строки 1220 */

static struct ocp_resource ocp_example_resource[] = {
	{
		OCP_MEM_RESOURCE(reg),
		.offset = 0x01000000, .size = 0x10000,
	},
	{
		OCP_EXT_RESOURCE(ts0),
		.offset = 0x01010000, .size = 0x10000, .irq_vec = 1,
		.extra = &(struct ptp_ocp_ext_info) {
			.index = 0,
			.irq_fcn = ptp_ocp_ts_irq,
			.enable = ptp_ocp_ts_enable,
		},
	},
	{
		OCP_EXT_RESOURCE(ts1),
		.offset = 0x01020000, .size = 0x10000, .irq_vec = 2,
		.extra = &(struct ptp_ocp_ext_info) {
			.index = 1,
			.irq_fcn = ptp_ocp_ts_irq,
			.enable = ptp_ocp_ts_enable,
		},
	},
	{
		OCP_EXT_RESOURCE(pps),
		.offset = 0x01030000, .size = 0x10000, .irq_vec = 3,
		.extra = &(struct ptp_ocp_ext_info) {
			.index = 2,
			.irq_fcn = ptp_ocp_ts_irq,
			.enable = ptp_ocp_ts_enable,
		},
	},
	{
		OCP_SERIAL_RESOURCE(gnss_port),
		.offset = 0x00160000 + 0x1000, .irq_vec = 4,
		.extra = &(struct ptp_ocp_serial_port) {
			.baud = 115200,
		},
	},
	{
		OCP_I2C_RESOURCE(i2c_ctrl),
		.offset = 0x00150000, .size = 0x10000, .irq_vec = 5,
		.extra = &(struct ptp_ocp_i2c_info) {
			.name = "xiic-i2c",
			.fixed_rate = 50000000,
			.data_size = sizeof(struct xiic_i2c_platform_data),
			.data = &(struct xiic_i2c_platform_data) {
				.num_devices = 2,
				.devices = (struct i2c_board_info[]) {
					{ I2C_BOARD_INFO("24c02", 0x50) },
					{ I2C_BOARD_INFO("24mac402", 0x58),
					  .platform_data = "mac" },
				},
			},
		},
	},
	{
		OCP_SPI_RESOURCE(spi_flash),
		.offset = 0x00310000, .size = 0x10000, .irq_vec = 6,
		.extra = &(struct ptp_ocp_flash_info) {
			.name = "xilinx_spi", .pci_offset = 0,
			.data_size = sizeof(struct xspi_platform_data),
			.data = &(struct xspi_platform_data) {
				.num_chipselect = 1,
				.bits_per_word = 8,
				.num_devices = 1,
				.force_irq = true,
				.devices = &(struct spi_board_info) {
					.modalias = "spi-nor",
				},
			},
		},
	},
	{
		OCP_MEM_RESOURCE(tod),
		.offset = 0x01050000, .size = 0x10000,
	},
	{
		OCP_MEM_RESOURCE(pps_select),
		.offset = 0x00130000, .size = 0x10000,
	},
	{
		OCP_MEM_RESOURCE(sma_map1),
		.offset = 0x00140000, .size = 0x10000,
	},
	{
		OCP_MEM_RESOURCE(sma_map2),
		.offset = 0x00220000, .size = 0x10000,
	},
	{ }
};

/* ========== ШАГ 3: Создать структуру данных драйвера ========== */
/* Добавить после существующих структур драйвера, например после строки 1235 */

static struct ocp_driver_data ocp_example_driver_data[] = {
	{
		.ocp_resource_msi = (struct ocp_resource *) (&ocp_example_resource),
		.ocp_resource_msix = (struct ocp_resource *) (&ocp_example_resource),
	},
	{ }
};

/* ========== ШАГ 4: Добавить устройство в таблицу PCI ========== */
/* Изменить существующую таблицу ptp_ocp_pcidev_id около строки 1238 */

static const struct pci_device_id ptp_ocp_pcidev_id[] = {
	{ PCI_DEVICE_DATA(FACEBOOK, TIMECARD, &ocp_fb_driver_data) },
	{ PCI_DEVICE_DATA(CELESTICA, TIMECARD, &ocp_fb_driver_data) },
	{ PCI_DEVICE_DATA(OROLIA, ARTCARD, &ocp_art_driver_data) },
	{ PCI_DEVICE_DATA(EXAMPLE, TIMECARD, &ocp_example_driver_data) },  /* <-- Добавить эту строку */
	{ }
};

/* ========== ОПЦИОНАЛЬНО: Функция инициализации платы ========== */
/* Если требуется специальная инициализация, добавить функцию */

static int ptp_ocp_example_board_init(struct ptp_ocp *bp, struct ocp_resource *r)
{
	struct ptp_ocp_ext_src *ext;
	int err;

	/* Пример инициализации */
	bp->tod_correction = 0;
	
	/* Настройка SMA коннекторов если необходимо */
	bp->sma_op = &ocp_fb_sma_op;  /* или создать свою структуру операций */

	/* Дополнительная настройка */
	ptp_ocp_sma_init(bp);

	/* Включение прерываний */
	ext = bp->ts0;
	if (ext)
		iowrite32(1, &ext->reg->enable);
	ext = bp->ts1;
	if (ext)
		iowrite32(1, &ext->reg->enable);

	return 0;
}

/* Затем добавить .setup = ptp_ocp_example_board_init в первый ресурс таблицы */

/* ========== ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ ========== */

/* Если устройство имеет особые SMA коннекторы, можно создать свою структуру операций */
static const struct ocp_sma_op ocp_example_sma_op = {
	.tbl		= { ocp_fb_sma_in, ocp_fb_sma_out },  /* или свои таблицы */
	.init		= ptp_ocp_fb_sma_init,  /* или своя функция инициализации */
	.get		= ptp_ocp_fb_sma_get,
	.set_input	= ptp_ocp_fb_sma_set_input,
	.set_output	= ptp_ocp_fb_sma_set_output,
};

/* ========== ПРОВЕРКА ========== */
/*
 * После добавления кода:
 * 1. Скомпилировать драйвер: make -C /lib/modules/$(uname -r)/build M=$PWD modules
 * 2. Загрузить модуль: sudo insmod ptp_ocp.ko
 * 3. Проверить dmesg: dmesg | tail -50
 * 4. Проверить обнаружение: lspci -d 1234:5678 -vvv
 * 5. Проверить устройство: ls -la /dev/ptp*
 */