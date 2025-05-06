#!/system/bin/sh

# 初始化模块路径
MODDIR=$MODPATH

# ===================== 前置检测 =====================
echo ""
echo "===== 更新日志验证 ====="
if [ ! -f "$MODDIR/更新日志.txt" ]; then
    echo "! 错误：缺失更新日志文件！"
    echo "! 安装已中止"
    exit 1
fi

yxy_value=$(grep -iE '^[[:space:]]*yxy[[:space:]]*=' "$MODDIR/更新日志.txt" | 
           tail -n 1 | 
           awk -F= '{print $2}' | 
           tr -d '[:space:]' | 
           tr '[:upper:]' '[:lower:]')

case "$yxy_value" in
    true)
        echo "- 验证通过，开始安装..." ;;
    false)
        echo "! 当前配置禁止安装！"
        echo "! 请仔细阅读模块里更新日志"
        exit 1 ;;
    *)
        echo "! 无效的yxy标记值：$yxy_value"
        echo "! 允许值：true"
        exit 1 ;;
esac

# ===================== 设备信息显示 =====================
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
get_device_info

# ===================== 目录初始化 =====================
mkdir -p $MODDIR/system/vendor/overlay
mkdir -p $MODDIR/system/product/app
mkdir -p $MODDIR/system/app

# ===================== 核心功能函数 =====================
volume_key() {
  while :; do
    getevent -qlc 1 | grep -qE 'KEY_VOLUMEUP' && { sleep 0.5; return 0; }
    getevent -qlc 1 | grep -qE 'KEY_VOLUMEDOWN' && { sleep 0.5; return 1; }
    sleep 0.1
  done
}

file_control() {
  echo "[$1/6] $2?
  (音量+启用，音量-不启用)"
  src="$MODDIR/yxy/$3"
  dest="$MODDIR/$4"

  if volume_key; then
    [ -e "$src" ] && mv -f "$src" "$dest"
    echo "- √ 已启用 ${5:-$3}"
    return 0
  else
    [ -e "$src" ] && rm -rf "$src"
    echo "- × 已删除 ${5:-$3}"
    return 1
  fi
}

# ===================== 功能配置流程 =====================
echo ""
echo "===== 功能配置 ====="

# 配置项1: OTA卡片
if file_control 1 "启用 OOS OTA 卡片" \
"QIUCIROMOTACard.apk" "system/vendor/overlay/QIUCIROMOTACard.apk" "OTA 组件"; then
  PUI_MODULE="/data/adb/modules/PUIThemeCustomized"
  if [ -d "$PUI_MODULE" ]; then
    delete_targets="
    $PUI_MODULE/product/overlay/PUIThemedSettingsInfoString.apk
    $PUI_MODULE/product/overlay/PUIThemedLogoInfoPicture.apk
    $PUI_MODULE/product/overlay/PUIThemedOTAInfoLogo.apk
    $PUI_MODULE/product/overlay/PuiThemeCustomizedDeviceOTACard.apk
    $PUI_MODULE/system/product/overlay/PUIThemedSettingsInfoString.apk
    $PUI_MODULE/system/product/overlay/PUIThemedLogoInfoPicture.apk
    $PUI_MODULE/system/product/overlay/PUIThemedOTAInfoLogo.apk
    $PUI_MODULE/system/product/overlay/PuiThemeCustomizedDeviceOTACard.apk
    "

    conflict_detected=$(echo "$delete_targets" | while read -r target_file; do
      [ -n "$target_file" ] && [ -e "$target_file" ] && { echo "1"; break; }
    done)

    if [ "$conflict_detected" = "1" ]; then
      echo ""
      echo "! 检测PUI主题冲突文件（不删除可能造成卡片显示问题）"
      echo "是否删除PUI主题冲突文件？"
      echo "音量+删除 / 音量-保留"

      if volume_key; then
        echo "- 正在清理冲突文件..."
        echo "$delete_targets" | while read -r target_file; do
          [ -n "$target_file" ] && [ -e "$target_file" ] && rm -f "$target_file" && echo "  - 已删除: ${target_file##*/}"
        done
      else
        echo "- 已保留PUI主题冲突文件"
      fi
    fi
  fi
fi

# 配置项2: 7+ Gen3介绍页
if file_control 2 "启用 7+ Gen3 介绍页及设置扩展" \
"com.oplus.Snapdragon.7+Gen3.apk" "system/vendor/overlay/com.oplus.Snapdragon.7+Gen3.apk" "芯片组件"; then
  xml_src="$MODDIR/yxy/feature_com.android.settings.xml"
  xml_dest="$MODDIR/my_product/etc/extension/feature_com.android.settings.xml"
  mkdir -p "$(dirname "$xml_dest")"
  mv -f "$xml_src" "$xml_dest" >/dev/null 2>&1
else
  rm -f "$MODDIR/yxy/feature_com.android.settings.xml" >/dev/null 2>&1
fi

# 配置项3: AI游戏助手
if file_control 3 "启用 AI 游戏助手" \
"AIPlaymate" "system/app/AIPlaymate" "游戏辅助模块"; then
    ai_config_src="$MODDIR/yxy/aiEngineConfig.xml"
    ai_config_dest="$MODDIR/my_product/etc/aiEngineConfig.xml"
    mkdir -p "$(dirname "$ai_config_dest")"
    mv -f "$ai_config_src" "$ai_config_dest" >/dev/null 2>&1
    mv -f "$MODDIR/yxy/COSA" "$MODDIR/product/app/" >/dev/null 2>&1
else
    rm -f "$MODDIR/yxy/aiEngineConfig.xml" >/dev/null 2>&1
    rm -rf "$MODDIR/yxy/COSA" >/dev/null 2>&1
fi

# 配置项5: 风驰内核
file_control 4 "启用游戏构架「UI」：风驰内核2.0" \
"com.oplus.OPlusGameKernel.apk" "system/vendor/overlay/com.oplus.OPlusGameKernel.apk" "游戏内核组件"

# 配置项6: 真实电量
{
echo ""
echo "[5/6] 启用真实电量显示
   (音量+启用，音量-不启用)"
service_script="$MODDIR/service.sh"
[ ! -f "$service_script" ] && { echo -e "#!/system/bin/sh\n" > "$service_script"; chmod 0755 "$service_script"; }

if volume_key; then
    if ! grep -qF 'chip_soc' "$service_script"; then
        cat >> "$service_script" << 'EOF'
mount --bind /sys/class/oplus_chg/battery/chip_soc /sys/class/power_supply/battery/capacity
EOF
        echo "- √ 电量显示已激活"
    fi
else
    echo "- × 已跳过电量配置"
fi
} 2>/dev/null

# 配置项7: AI传送门
file_control 6 "启用 AI 传送门" \
"RomCommonService" "system/product/app/RomCommonService" "AI传送门组件"

echo "=====正在安装相机补全====="
CLEAN="$MODDIR"
for ZIPFILE in $CLEAN/*.zip; do
    install_module
done

echo "安装成功"

rm -rf "$MODDIR/yxy" 
rm -rf "$MODDIR/OnePlus ACE 3V 相机.zip" 

if [ -d "/data/adb/modules/ab_optimizer" ]; then
    echo ""
    echo "===== 检测到ab_optimizer模块 ====="
  
    module_prop="$MODDIR/module.prop"
    original_desc="一加Ace3V定制模块\[弃舰版\]"
    append_txt=" 本模块兼容「Hydrostellaire 沨莹」如需卸载模块请点击下面执行取消兼容"
    
    # 安全追加模式
    sed -i "/^description=.*$original_desc/ {
        s/\(.*\)/\1$append_txt/
        t
        b
    }" "$module_prop" 2>/dev/null
    
    # 备用方案：当原始描述格式异常时
    if ! grep -q "$append_txt" "$module_prop"; then
        sed -i "s/^description=.*/&$append_txt/" "$module_prop" 2>/dev/null
    fi
fi
    # 创建模块备份
    backup_dir="$MODDIR/backups"
    mkdir -p "$backup_dir"
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="$backup_dir/ab_optimizer_backup_$timestamp.tar.gz"
    if tar -czf "$backup_file" -C /data/adb/modules_update ab_optimizer 2>/dev/null; then
        file_size=$(du -sh "$backup_file" | awk '{print $1}')
        echo "- 已创建模块备份：${backup_file##*/} (${file_size}B)"
    fi
    
    # 合并my_product目录
    src_root="$MODDIR/my_product"
    dest_root="/data/adb/modules_update/ab_optimizer/my_product"
    if (cd "$src_root" && tar cf - .) | (mkdir -p "$dest_root" && cd "$dest_root" && tar xf - 2>/dev/null); then
        rm -rf "$src_root"
        sed -i '\#overlay_mount "/my_product/#d' "$MODDIR/post-fs-data.sh" 2>/dev/null
        touch "/data/adb/modules_update/ab_optimizer/update"
        echo "- 兼容成功，重启后生效"
    else
        echo "! 文件合并失败，请手动操作"
    fi

echo ""
echo "===== 配置结束 ====="