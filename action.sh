#!/system/bin/sh

# 设备信息检测函数
get_device_info() {
    echo ""
    echo "===== 设备信息 ====="
    echo "机型：$(getprop ro.product.vendor.model)"
    echo "市场名：$(getprop ro.vendor.oplus.market.name)"
    echo "内核版本：$(uname -r)"
    echo "ColorOS版本：$(getprop persist.sys.oplus.ota_ver_display)"
    echo "Android版本：$(getprop ro.build.version.release) (SDK $(getprop ro.build.version.sdk))"
    echo "安全补丁：$(getprop ro.build.version.security_patch)"
    echo "基带版本：$(getprop gsm.version.baseband)"
    echo "存储容量：$(df -h /data | awk 'NR==2{print $2}')"
    echo "====================="
}

# 电池信息检测函数
get_battery_info() {
    getNum() {
      [ ${#1} -gt 6 ] && echo -n ${1:0:4} || echo -n $1
    }

    echo -e "\n===== 电池信息详情 ====="
    echo -e "\n- 开始输出电池信息\n"

    now=''
    full=''
    design=''

    # 电池容量检测
    for file in /sys/class/power_supply/bms/fcc /sys/class/power_supply/bms/charge_full /sys/class/oplus_chg/battery/battery_fcc /sys/class/power_supply/battery/charge_full; do
      test -f $file && {
        chmod a+r $file
        full="$(getNum "$(head -n 1 $file 2>/dev/null)")"
        [ "$full" -lt 0 ] && continue
        echo " - 电池容量: ${full}毫安"
        break
      }
    done

    # 设计容量检测
    for file in /sys/class/power_supply/bms/charge_full_design /sys/class/oplus_chg/battery/design_capacity /sys/class/power_supply/battery/charge_full_design; do
      test -f $file && {
        chmod a+r $file
        design="$(getNum "$(head -n 1 $file 2>/dev/null)")"
        [ "$design" -lt 0 ] && continue
        echo " - 设计容量: ${design}毫安"
        break
      }
    done

    # 循环次数检测
    for file in /sys/class/power_supply/bms/cycle_count /sys/class/oplus_chg/battery/battery_cc /sys/class/power_supply/battery/cycle_count; do
      test -f $file && {
        chmod a+r $file
        value="$(head -n 1 $file 2>/dev/null)"
        [ "$value" -lt 0 ] && continue
        echo " - 循环次数: ${value}次"
        break
      }
    done

    # 健康度检测
    for file in /sys/class/xm_power/fg_master/soh /sys/class/power_supply/bms/soh /sys/class/oplus_chg/battery/battery_soh; do
      test -f $file && {
        chmod a+r $file
        value="$(head -n 1 $file 2>/dev/null)"
        [ "$value" -lt 0 ] && continue
        echo " - 电池健康: ${value}%"
        break
      }
    done

    # 综合计算
    [ ! -z "$full" ] && [ ! -z "$design" ] && [ "$full" -ge 0 ] && [ "$design" -ge 0 ] && echo " - 计算健康: $(printf "%.2f\n" "$(echo -n "$full $design" | awk '{print $1 * 100 / $2}')")%"

    # 当前电量检测
    for file in /sys/class/power_supply/bms/rm /sys/class/oplus_chg/battery/battery_rm /sys/class/power_supply/battery/charge_counter; do
      test -f $file && {
        chmod a+r $file
        now="$(getNum "$(head -n 1 $file 2>/dev/null)")"
        [ "$now" -lt 0 ] && continue
        echo " - 电池电量: ${now}毫安"
        break
      }
    done

    # 补充检测
    test -f /sys/class/power_supply/battery/capacity && {
      chmod a+r /sys/class/power_supply/battery/capacity
      echo " - 当前电量: $(head -n 1 /sys/class/power_supply/battery/capacity 2>/dev/null)%"
    }

    test -f /sys/class/power_supply/bms/capacity_raw && {
      chmod a+r /sys/class/power_supply/bms/capacity_raw
      echo " - 真实电量: $(head -n 1 /sys/class/power_supply/bms/capacity_raw | sed 's/\(.*\)\(.\)\(.\)$/\1.\2\3/' 2>/dev/null)%"
    }

    for file in /sys/class/power_supply/bms/rsoc /sys/class/oplus_chg/battery/chip_soc /sys/class/qcom-battery/fg1_rsoc; do
      test -f $file && {
        chmod a+r $file
        value="$(head -n 1 $file 2>/dev/null)"
        [ "$value" -lt 0 ] && continue
        echo " - 真实电量: ${value}%"
        break
      }
    done

    # 综合计算
    [ ! -z "$full" ] && [ ! -z "$now" ] && [ "$full" -ge 0 ] && [ "$now" -ge 0 ] && echo " - 计算电量: $(printf "%.2f\n" "$(echo -n "$now $full" | awk '{print $1 * 100 / $2}')")%"

    echo -e "\n\n  - 脚本作者：酷安@芊莳草 哔哩哔哩@安音咲汀 其他@咲汀\n\n"
}

volume_key() {
    while true; do
        getevent -qlc 1 | grep -qE 'KEY_VOLUMEUP *DOWN' && { sleep 0.5; return 0; }
        getevent -qlc 1 | grep -qE 'KEY_VOLUMEDOWN *DOWN' && { sleep 0.5; return 1; }
        sleep 0.1
    done
}

# 完整卸载模块函数
uninstall_module() {
    echo ""
    echo "===== 开始卸载操作 ====="
    
    # 删除ab_optimizer模块
    echo "- 正在清理兼容模块..."
    if [ -d "/data/adb/modules/ab_optimizer" ]; then
        rm -rf "/data/adb/modules/ab_optimizer" && echo "  √ 已删除ab_optimizer模块"
    else
        echo "  ! 未找到ab_optimizer模块"
    fi
    
    # 恢复备份文件
    echo "- 正在恢复原始配置..."
    backup_dir="/data/adb/modules/ColorOS-OnePlus_ACE3V/backups"
    if [ -d "$backup_dir" ]; then
        latest_backup=$(ls -t "$backup_dir"/*.tar.gz 2>/dev/null | head -n1)
        if [ -f "$latest_backup" ]; then
            echo "  √ 找到最新备份：${latest_backup##*/}"
            if tar -xzf "$latest_backup" -C /data/adb/modules; then
                echo "  √ 备份恢复成功"
            else
                echo "  ! 备份解压失败"
            fi
        else
            echo "  ! 未找到有效备份文件"
        fi
    else
        echo "  ! 备份目录不存在"
    fi
    
    # 删除本模块
    echo "- 正在移除本模块..."
    if [ -d "/data/adb/modules/ColorOS-OnePlus_ACE3V" ]; then
        rm -rf "/data/adb/modules/ColorOS-OnePlus_ACE3V" && echo "  √ 模块已移除"
    else
        echo "  ! 模块目录不存在"
    fi
    
    # 重启设备
    echo "- 即将重启设备..."
    echo "按任意键立即重启..."
    volume_key  # 等待确认
    reboot
}

# 主程序流程
clear
get_device_info

echo ""
echo "===== 功能菜单 ====="
echo "1. 查看电池详细信息"
echo "2. 卸载本模块"
echo "==================="

# 选项选择
selected=1
while :; do
    case $selected in
        1) echo "当前选择：[1] 查看电池详细信息";;
        2) echo "当前选择：[2] 卸载本模块";;
    esac
    
    echo "音量+切换选项 | 音量-确认选择"
    if volume_key; then
        selected=$((selected % 2 + 1))
    else
        break
    fi
    clear
    get_device_info
done

# 执行操作
case $selected in
    1)
        clear
        get_battery_info
        echo ""
        echo "按任意键返回..."
        volume_key
        ;;
    2)
        clear
        echo "! 确认要卸载本模块吗？"
        echo "这将执行以下操作："
        echo "2，取消兼容ab_optimizer模块"
        echo "3. 删除本模块并重启设备"
        echo ""
        echo "音量+ - 确认卸载"
        echo "音量- - 取消操作"
        
        if volume_key; then
            uninstall_module
        else
            echo "- 已取消卸载操作"
            exit 0
        fi
        ;;
esac

echo "- 操作执行完毕"
exit 0