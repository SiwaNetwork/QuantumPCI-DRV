/*
 * Пример реализации управления питанием для драйвера PTP OCP
 * 
 * Этот код демонстрирует, как можно добавить поддержку suspend/resume
 * в существующий драйвер ptp_ocp.c
 */

#include <linux/pm.h>
#include <linux/pm_runtime.h>

/* Структура для сохранения состояния устройства при suspend */
struct ptp_ocp_saved_state {
	/* Основные регистры */
	u32 ctrl;
	u32 select;
	u32 servo_offset_p;
	u32 servo_offset_i;
	u32 servo_drift_p;
	u32 servo_drift_i;
	
	/* Конфигурация SMA */
	u32 sma_config[4];
	
	/* Конфигурация сигналов */
	u32 signal_config[4];
	
	/* Состояние GNSS */
	u32 tod_ctrl;
	u32 utc_tai_offset;
	
	/* Состояние прерываний */
	u32 irq_mask[16];
};

/*
 * ptp_ocp_save_state - Сохранение состояния устройства
 * @bp: указатель на структуру устройства
 * 
 * Сохраняет критические регистры и настройки перед переходом в спящий режим
 */
static int ptp_ocp_save_state(struct ptp_ocp *bp)
{
	struct ptp_ocp_saved_state *state;
	int i;
	
	state = kzalloc(sizeof(*state), GFP_KERNEL);
	if (!state)
		return -ENOMEM;
	
	/* Сохраняем основные регистры */
	state->ctrl = ioread32(&bp->reg->ctrl);
	state->select = ioread32(&bp->reg->select);
	state->servo_offset_p = ioread32(&bp->reg->servo_offset_p);
	state->servo_offset_i = ioread32(&bp->reg->servo_offset_i);
	state->servo_drift_p = ioread32(&bp->reg->servo_drift_p);
	state->servo_drift_i = ioread32(&bp->reg->servo_drift_i);
	
	/* Сохраняем конфигурацию SMA */
	for (i = 0; i < 4; i++) {
		if (bp->sma[i].mode != SMA_MODE_DISABLED)
			state->sma_config[i] = bp->sma[i].mode;
	}
	
	/* Сохраняем конфигурацию сигналов */
	for (i = 0; i < 4; i++) {
		if (bp->signal[i].running)
			state->signal_config[i] = 1;
	}
	
	/* Сохраняем состояние TOD */
	if (bp->tod) {
		state->tod_ctrl = ioread32(&bp->tod->ctrl);
		state->utc_tai_offset = bp->utc_tai_offset;
	}
	
	/* Сохраняем маски прерываний */
	if (bp->ts0)
		state->irq_mask[0] = ioread32(&bp->ts0->reg->intr_mask);
	if (bp->ts1)
		state->irq_mask[1] = ioread32(&bp->ts1->reg->intr_mask);
	/* ... и так далее для других источников прерываний */
	
	bp->saved_state = state;
	
	dev_info(&bp->pdev->dev, "State saved for suspend\n");
	return 0;
}

/*
 * ptp_ocp_restore_state - Восстановление состояния устройства
 * @bp: указатель на структуру устройства
 * 
 * Восстанавливает сохраненное состояние после выхода из спящего режима
 */
static int ptp_ocp_restore_state(struct ptp_ocp *bp)
{
	struct ptp_ocp_saved_state *state = bp->saved_state;
	int i;
	
	if (!state) {
		dev_err(&bp->pdev->dev, "No saved state to restore\n");
		return -EINVAL;
	}
	
	/* Восстанавливаем основные регистры */
	iowrite32(state->ctrl & ~OCP_CTRL_ENABLE, &bp->reg->ctrl);
	iowrite32(state->select, &bp->reg->select);
	iowrite32(state->servo_offset_p, &bp->reg->servo_offset_p);
	iowrite32(state->servo_offset_i, &bp->reg->servo_offset_i);
	iowrite32(state->servo_drift_p, &bp->reg->servo_drift_p);
	iowrite32(state->servo_drift_i, &bp->reg->servo_drift_i);
	
	/* Восстанавливаем конфигурацию SMA */
	for (i = 0; i < 4; i++) {
		if (state->sma_config[i]) {
			char buf[32];
			snprintf(buf, sizeof(buf), "%d", state->sma_config[i]);
			ptp_ocp_sma_store(bp, buf, i + 1);
		}
	}
	
	/* Восстанавливаем TOD */
	if (bp->tod && state->tod_ctrl) {
		iowrite32(state->tod_ctrl, &bp->tod->ctrl);
		bp->utc_tai_offset = state->utc_tai_offset;
		ptp_ocp_utc_distribute(bp, state->utc_tai_offset);
	}
	
	/* Восстанавливаем маски прерываний */
	if (bp->ts0)
		iowrite32(state->irq_mask[0], &bp->ts0->reg->intr_mask);
	if (bp->ts1)
		iowrite32(state->irq_mask[1], &bp->ts1->reg->intr_mask);
	
	/* Включаем устройство */
	iowrite32(state->ctrl | OCP_CTRL_ENABLE, &bp->reg->ctrl);
	
	/* Перезапускаем сторожевой таймер */
	if (bp->watchdog.function)
		mod_timer(&bp->watchdog, jiffies + HZ);
	
	kfree(state);
	bp->saved_state = NULL;
	
	dev_info(&bp->pdev->dev, "State restored after resume\n");
	return 0;
}

/*
 * ptp_ocp_suspend - Обработчик suspend
 * @dev: указатель на устройство
 * 
 * Вызывается при переходе системы в спящий режим
 */
static int ptp_ocp_suspend(struct device *dev)
{
	struct pci_dev *pdev = to_pci_dev(dev);
	struct devlink *devlink = pci_get_drvdata(pdev);
	struct ptp_ocp *bp = devlink_priv(devlink);
	int err;
	
	dev_info(dev, "Suspending PTP OCP device\n");
	
	/* Останавливаем сторожевой таймер */
	del_timer_sync(&bp->watchdog);
	
	/* Отключаем все активные сигналы */
	for (int i = 0; i < 4; i++) {
		if (bp->signal[i].running) {
			struct ptp_clock_request rq = {
				.type = PTP_CLK_REQ_PEROUT,
				.perout.index = i
			};
			ptp_ocp_enable(bp->ptp, &rq, 0);
		}
	}
	
	/* Сохраняем состояние */
	err = ptp_ocp_save_state(bp);
	if (err)
		return err;
	
	/* Отключаем прерывания */
	if (bp->n_irqs)
		pci_disable_msix(pdev);
	
	/* Переводим устройство в D3 */
	pci_save_state(pdev);
	pci_disable_device(pdev);
	pci_set_power_state(pdev, PCI_D3hot);
	
	return 0;
}

/*
 * ptp_ocp_resume - Обработчик resume
 * @dev: указатель на устройство
 * 
 * Вызывается при выходе системы из спящего режима
 */
static int ptp_ocp_resume(struct device *dev)
{
	struct pci_dev *pdev = to_pci_dev(dev);
	struct devlink *devlink = pci_get_drvdata(pdev);
	struct ptp_ocp *bp = devlink_priv(devlink);
	int err;
	
	dev_info(dev, "Resuming PTP OCP device\n");
	
	/* Восстанавливаем питание устройства */
	pci_set_power_state(pdev, PCI_D0);
	pci_restore_state(pdev);
	
	err = pci_enable_device(pdev);
	if (err) {
		dev_err(dev, "Failed to enable device: %d\n", err);
		return err;
	}
	
	/* Восстанавливаем прерывания */
	if (bp->n_irqs) {
		err = pci_enable_msix_range(pdev, bp->msix_entries,
					    1, bp->n_irqs);
		if (err < 0) {
			dev_err(dev, "Failed to enable MSI-X: %d\n", err);
			goto err_disable;
		}
	}
	
	/* Проверяем, что устройство отвечает */
	if (ioread32(&bp->reg->version) == 0xffffffff) {
		dev_err(dev, "Device not responding after resume\n");
		err = -EIO;
		goto err_disable_msix;
	}
	
	/* Восстанавливаем состояние */
	err = ptp_ocp_restore_state(bp);
	if (err)
		goto err_disable_msix;
	
	/* Синхронизируем время с источником */
	if (bp->pps) {
		struct ptp_clock_request rq = {
			.type = PTP_CLK_REQ_PPS,
			.pps.enable = 1
		};
		ptp_ocp_enable(bp->ptp, &rq, 1);
	}
	
	dev_info(dev, "Resume completed successfully\n");
	return 0;
	
err_disable_msix:
	if (bp->n_irqs)
		pci_disable_msix(pdev);
err_disable:
	pci_disable_device(pdev);
	return err;
}

/*
 * ptp_ocp_runtime_suspend - Runtime PM suspend
 * @dev: указатель на устройство
 * 
 * Вызывается при неактивности устройства
 */
static int ptp_ocp_runtime_suspend(struct device *dev)
{
	struct pci_dev *pdev = to_pci_dev(dev);
	struct devlink *devlink = pci_get_drvdata(pdev);
	struct ptp_ocp *bp = devlink_priv(devlink);
	
	/* Переводим неиспользуемые блоки в режим низкого потребления */
	if (bp->image) {
		/* Отключаем неиспользуемые блоки FPGA */
		iowrite32(0x0, &bp->image->power_ctrl);
	}
	
	return 0;
}

/*
 * ptp_ocp_runtime_resume - Runtime PM resume
 * @dev: указатель на устройство
 * 
 * Вызывается при обращении к устройству
 */
static int ptp_ocp_runtime_resume(struct device *dev)
{
	struct pci_dev *pdev = to_pci_dev(dev);
	struct devlink *devlink = pci_get_drvdata(pdev);
	struct ptp_ocp *bp = devlink_priv(devlink);
	
	/* Включаем все блоки FPGA */
	if (bp->image) {
		iowrite32(0xffffffff, &bp->image->power_ctrl);
		/* Ждем стабилизации */
		usleep_range(100, 200);
	}
	
	return 0;
}

/* Структура PM операций */
static const struct dev_pm_ops ptp_ocp_pm_ops = {
	.suspend = ptp_ocp_suspend,
	.resume = ptp_ocp_resume,
	.freeze = ptp_ocp_suspend,
	.thaw = ptp_ocp_resume,
	.poweroff = ptp_ocp_suspend,
	.restore = ptp_ocp_resume,
	.runtime_suspend = ptp_ocp_runtime_suspend,
	.runtime_resume = ptp_ocp_runtime_resume,
};

/* Обновленная структура PCI драйвера с поддержкой PM */
static struct pci_driver ptp_ocp_driver = {
	.name		= KBUILD_MODNAME,
	.id_table	= ptp_ocp_pcidev_id,
	.probe		= ptp_ocp_probe,
	.remove		= ptp_ocp_remove,
	.driver.pm	= &ptp_ocp_pm_ops,  /* Добавляем поддержку PM */
};

/* 
 * Дополнительные изменения в probe функции:
 * 
 * В функции ptp_ocp_probe() нужно добавить:
 */
static int ptp_ocp_probe_with_pm(struct pci_dev *pdev,
				 const struct pci_device_id *id)
{
	/* ... существующий код probe ... */
	
	/* Включаем runtime PM */
	pm_runtime_set_autosuspend_delay(&pdev->dev, 5000); /* 5 секунд */
	pm_runtime_use_autosuspend(&pdev->dev);
	pm_runtime_put_noidle(&pdev->dev);
	pm_runtime_allow(&pdev->dev);
	
	dev_info(&pdev->dev, "Power management enabled\n");
	
	return 0;
}

/*
 * В функции ptp_ocp_remove() нужно добавить:
 */
static void ptp_ocp_remove_with_pm(struct pci_dev *pdev)
{
	/* Отключаем runtime PM */
	pm_runtime_get_noresume(&pdev->dev);
	pm_runtime_forbid(&pdev->dev);
	
	/* ... существующий код remove ... */
}