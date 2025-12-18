#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/timekeeping.h>
#include <linux/time.h>
#include <linux/version.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Student");
MODULE_DESCRIPTION("TSU Kernel Module: Gagarin Mirror Date");

#define PROCFS_NAME "tsulab"

static struct proc_dir_entry *out_proc_file = NULL;

// Старт Ю.А. Гагарина: 12 апреля 1961 г., 06:07:00 UTC
// Unix timestamp: -283993980 секунд
static const time64_t GAGARIN_TIMESTAMP = -283993980LL;

static void calculate_mirror_date(char *buffer, size_t max_len)
{
    time64_t now = ktime_get_real_seconds();
    // Зеркальная точка: K - (now - K) = 2*K - now
    time64_t mirror_time = 2 * GAGARIN_TIMESTAMP - now;

    struct tm mirror_tm;
    // Преобразуем время в UTC (смещение = 0)
    time64_to_tm(mirror_time, 0, &mirror_tm);

    snprintf(buffer, max_len,
        "Зеркальная дата относительно старта Гагарина (12.04.1961 06:07 UTC):\n"
        "%04d-%02d-%02d %02d:%02d UTC\n",
        mirror_tm.tm_year + 1900,
        mirror_tm.tm_mon + 1,
        mirror_tm.tm_mday,
        mirror_tm.tm_hour,
        mirror_tm.tm_min
    );
}

static ssize_t procfile_read(struct file *file, char __user *user_buf,
                             size_t count, loff_t *ppos)
{
    char msg[256];
    int len;

    if (*ppos > 0)
        return 0;

    calculate_mirror_date(msg, sizeof(msg));
    len = strlen(msg);

    if (copy_to_user(user_buf, msg, len))
        return -EFAULT;

    *ppos = len;
    return len;
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 6, 0)
static const struct proc_ops proc_file_ops = {
    .proc_read = procfile_read,
};
#else
static const struct file_operations proc_file_ops = {
    .read = procfile_read,
};
#endif

static int __init tsu_init(void)
{
    pr_info("Welcome to the Tomsk State University\n");
    out_proc_file = proc_create(PROCFS_NAME, 0444, NULL, &proc_file_ops);
    if (!out_proc_file) {
        pr_err("Failed to create /proc/%s\n", PROCFS_NAME);
        return -ENOMEM;
    }
    pr_info("/proc/%s created\n", PROCFS_NAME);
    return 0;
}

static void __exit tsu_exit(void)
{
    proc_remove(out_proc_file);
    pr_info("/proc/%s removed\n", PROCFS_NAME);
    pr_info("Tomsk State University forever!\n");
}

module_init(tsu_init);
module_exit(tsu_exit);
