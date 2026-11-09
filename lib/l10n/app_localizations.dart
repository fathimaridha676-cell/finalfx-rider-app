import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      // Nav
      'nav_home': 'Home',
      'nav_orders': 'Orders',
      'nav_profile': 'Profile',

      // Duty
      'on_duty': 'ON DUTY',
      'off_duty': 'OFF DUTY',
      'online': 'ONLINE',
      'offline': 'OFFLINE',
      'swipe_online': 'SWIPE ONLINE',
      'swipe_offline': 'SWIPE OFFLINE',

      // Stats
      'stats_title': "Today's Statistics",
      'performance_overview': 'Performance Overview',
      'today': 'Today',
      'total': 'Total',
      'total_assigned': 'Total Assigned',
      'pending': 'Pending',
      'delivered': 'Delivered',
      'cancelled': 'Cancelled',
      'digital_menu': 'Digital Menu',

      // Mission & Active Order
      'current_mission': 'Active Order',
      'active_order': 'Active Order',
      'out_for_delivery': 'Out For Delivery',
      'all_caught_up': 'All Caught Up!',
      'no_pending_deliveries': 'You have no pending deliveries right now.',
      'orders_queue': 'Delivery Orders Queue',
      'orders_queue_desc': 'View all orders, customer locations & receipts',
      'open': 'Open',

      // Stages
      'stage_all': 'All',
      'stage_assigned': 'Assigned',
      'stage_shop_picked': 'Shop Picked',
      'stage_on_the_way': 'On the Way',

      // Order Card Details
      'order_type': 'Order Type',
      'home_delivery': 'HomeDelivery',
      'customer_name': 'Customer Name',
      'phone_number': 'Phone Number',
      'delivery_address': 'Delivery Address',
      'track_map': 'TRACK MAP',
      'pick_from_shop': 'PICK FROM SHOP',
      'start_ride': 'START RIDE',
      'arrived': 'ARRIVED',
      'call': 'Call',
      'open_google_maps': 'Open in Google Maps',
      'destination': 'Destination',
      'rider_location': 'Your Location',

      // Orders tab
      'my_deliveries': 'My Deliveries',
      'tab_active': 'Active',
      'tab_delivered': 'Delivered',
      'tab_cancelled': 'Cancelled',
      'tab_all': 'All',
      'no_active_orders': 'No Active Deliveries',
      'no_delivered_orders': 'No Completed Deliveries',
      'no_cancelled_orders': 'No Cancelled Deliveries',
      'no_orders_found': 'No Orders Found',
      'empty_active_desc': 'Assigned orders will show up here automatically.',
      'empty_cancelled_desc': 'Orders cancelled by you or store will appear here.',
      'items_count': 'Items',
      'item_single': 'Item',

      // Collect Payment & OTP
      'collect_payment': 'Collect Payment',
      'order_hash': 'Order #',
      'customer_delivery_otp': 'Customer Delivery OTP',
      'otp_instruction': 'Enter 4-digit PIN given by customer upon delivery handover.',
      'verify': 'Verify',
      'otp_verified': 'OTP Verified',
      'invalid_otp': 'Invalid PIN. Please ask customer for correct 4-digit PIN.',
      'customer_info': 'Customer Info',
      'items_ordered': 'Items Ordered',
      'subtotal': 'Subtotal',
      'tax_vat': 'Tax (VAT)',
      'delivery_charge': 'Delivery Charge',
      'total_due': 'Total Due',
      'split_payment': 'Split Payment',
      'split_instruction': 'Enter amount per method — total must equal',
      'cash': 'Cash',
      'card_bank': 'Card / Bank',
      'upi_qr': 'UPI / QR',
      'allocated': 'Allocated',
      'amount_to_collect': 'Amount to collect',
      'otp_required_warning': 'Customer OTP PIN verification required',
      'amount_mismatch_warning': 'Allocated amount must equal total due',
      'confirm_delivery_collect': 'Confirm Delivery & Collect',
      'delivery_completed_success': 'Delivery completed and payment confirmed!',

      // Confirmation Dialogs
      'confirm_pick_shop_title': 'Pick from Shop?',
      'confirm_pick_shop_msg': 'Confirm that you have collected the order from the outlet.',
      'confirm_start_ride_title': 'Start Ride?',
      'confirm_start_ride_msg': 'Confirm that you are departing for delivery.',
      'confirm_arrived_title': 'Arrived at Destination?',
      'confirm_arrived_msg': 'Confirm that you have arrived at the customer address.',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'confirm_delivered': 'Confirm Delivered',
      'confirm_delivered_title': 'Mark as Delivered?',
      'confirm_delivered_msg': 'Confirm that order has been handed over to customer.',
      'cancel_delivery_title': 'Cancel Delivery?',
      'cancel_reason_prompt': 'Please specify the reason for cancelling:',
      'confirm_cancel': 'Confirm Cancel',
      'go_back': 'Go Back',
      'reason_prefix': 'Reason:',
      'cancelled_by_admin': 'Cancelled by Store Admin',
      'cancelled_by_rider': 'Cancelled by You (Rider)',
      'order_cancelled': 'Order Cancelled',

      // Profile & Settings
      'my_profile': 'My Profile',
      'settings': 'Settings',
      'branch_details': 'Branch Details',
      'branch_name': 'Branch Name',
      'arabic_name': 'Arabic Name',
      'address': 'Address',
      'arabic_address': 'Arabic Address',
      'contact': 'Contact',
      'language': 'Language (اللغة)',
      'theme': 'Theme',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode (Default)',
      'delete_account': 'Delete Account',
      'logout': 'Logout',
      'sign_out': 'Sign Out',
      'sign_out_prompt': 'Are you sure you want to log out from the Rider Portal?',
      'delete_account_title': 'Delete Account?',
      'delete_account_msg': 'Account deletion requests must be confirmed with your outlet manager. Would you like to submit a deactivation request?',
      'submit_request': 'Submit Request',
      'select_language': 'Select Language',
      'lang_changed_toast': 'Language changed successfully to English',
      'close': 'Close',
      'outlet_name': 'Outlet Name',
      'brand': 'Brand',
      'status': 'Status',
      'active_rider': 'Active Delivery Driver',
      'inactive_rider': 'Inactive',
      'version': 'FX Merchant Rider • Version 1.0.0',
    },
    'ar': {
      // Nav
      'nav_home': 'الرئيسية',
      'nav_orders': 'الطلبات',
      'nav_profile': 'الملف الشخصي',

      // Duty
      'on_duty': 'في الخدمة',
      'off_duty': 'خارج الخدمة',
      'online': 'متصل',
      'offline': 'غير متصل',
      'swipe_online': 'اسحب للاتصال',
      'swipe_offline': 'اسحب لإلغاء الاتصال',

      // Stats
      'stats_title': 'إحصائيات اليوم',
      'performance_overview': 'نظرة عامة على الأداء',
      'today': 'اليوم',
      'total': 'الإجمالي',
      'total_assigned': 'إجمالي المعين',
      'pending': 'قيد الانتظار',
      'delivered': 'تم التوصيل',
      'cancelled': 'ملغي',
      'digital_menu': 'قائمة رقمية',

      // Mission & Active Order
      'current_mission': 'الطلب النشط',
      'active_order': 'الطلب النشط',
      'out_for_delivery': 'خرج للتوصيل',
      'all_caught_up': 'لا توجد مهام حالية!',
      'no_pending_deliveries': 'ليس لديك أي طلبات معلقة الآن.',
      'orders_queue': 'قائمة طلبات التوصيل',
      'orders_queue_desc': 'عرض كافة الطلبات وعناوين العملاء والفواتير',
      'open': 'فتح',

      // Stages
      'stage_all': 'الكل',
      'stage_assigned': 'تم التعيين',
      'stage_shop_picked': 'تم الاستلام',
      'stage_on_the_way': 'في الطريق',

      // Order Card Details
      'order_type': 'نوع الطلب',
      'home_delivery': 'توصيل للمنزل',
      'customer_name': 'اسم العميل',
      'phone_number': 'رقم الهاتف',
      'delivery_address': 'عنوان التوصيل',
      'track_map': 'تتبع الخريطة',
      'pick_from_shop': 'استلام من المتجر',
      'start_ride': 'بدء الرحلة',
      'arrived': 'وصلت للوجهة',
      'call': 'اتصال',
      'open_google_maps': 'فتح في خرائط جوجل',
      'destination': 'وجهة التوصيل',
      'rider_location': 'موقعك الحالي',

      // Orders tab
      'my_deliveries': 'توصيلاتي',
      'tab_active': 'النشطة',
      'tab_delivered': 'المكتملة',
      'tab_cancelled': 'الملغية',
      'tab_all': 'الكل',
      'no_active_orders': 'لا توجد طلبات نشطة',
      'no_delivered_orders': 'لا توجد طلبات مكتملة',
      'no_cancelled_orders': 'لا توجد طلبات ملغية',
      'no_orders_found': 'لم يتم العثور على طلبات',
      'empty_active_desc': 'الطلبات المسندة إليك ستظهر هنا تلقائياً.',
      'empty_cancelled_desc': 'الطلبات الملغية منك أو من المتجر ستظهر هنا.',
      'items_count': 'أصناف',
      'item_single': 'صنف',

      // Collect Payment & OTP
      'collect_payment': 'تحصيل المبلغ والتوصيل',
      'order_hash': 'طلب رقم #',
      'customer_delivery_otp': 'رمز التحقق من العميل (OTP)',
      'otp_instruction': 'أدخل الرمز المكون من 4 أرقام المستلم من العميل عند التسليم.',
      'verify': 'تحقق',
      'otp_verified': 'تم التحقق من الرمز',
      'invalid_otp': 'الرمز غير صحيح، يرجى طلب الرمز الصحيح من العميل.',
      'customer_info': 'بيانات العميل',
      'items_ordered': 'الأصناف المطلوبة',
      'subtotal': 'المجموع الفرعي',
      'tax_vat': 'ضريبة القيمة المضافة',
      'delivery_charge': 'رسوم التوصيل',
      'total_due': 'المبلغ الإجمالي',
      'split_payment': 'تقسيم الدفع',
      'split_instruction': 'أدخل المبلغ لكل وسيلة — يجب أن يطابق الإجمالي',
      'cash': 'نقداً (كاش)',
      'card_bank': 'بطاقة / شبكة',
      'upi_qr': 'دفع إلكتروني / QR',
      'allocated': 'المبلغ الموزع',
      'amount_to_collect': 'المبلغ المطلوب تحصيله',
      'otp_required_warning': 'مطلوب إدخال رمز التحقق (OTP) أولاً',
      'amount_mismatch_warning': 'المبلغ الموزع يجب أن يساوي الإجمالي',
      'confirm_delivery_collect': 'تأكيد التسليم والتحصيل',
      'delivery_completed_success': 'تم إكمال التوصيل وتأكيد استلام المبلغ بنجاح!',

      // Confirmation Dialogs
      'confirm_pick_shop_title': 'استلام من المتجر؟',
      'confirm_pick_shop_msg': 'تأكيد استلامك للطلب من الفرع بنجاح.',
      'confirm_start_ride_title': 'بدء الرحلة؟',
      'confirm_start_ride_msg': 'تأكيد الانطلاق لبدء توصيل الطلب للعميل.',
      'confirm_arrived_title': 'وصلت للوجهة؟',
      'confirm_arrived_msg': 'تأكيد وصولك إلى عنوان العميل بنجاح.',
      'confirm': 'تأكيد',
      'cancel': 'إلغاء',
      'confirm_delivered': 'تأكيد التسليم',
      'confirm_delivered_title': 'تأكيد التوصيل؟',
      'confirm_delivered_msg': 'يرجى تأكيد تسليم هذا الطلب للعميل بنجاح.',
      'cancel_delivery_title': 'إلغاء التوصيل؟',
      'cancel_reason_prompt': 'يرجى تحديد سبب إلغاء هذا الطلب:',
      'confirm_cancel': 'تأكيد الإلغاء',
      'go_back': 'رجوع',
      'reason_prefix': 'السبب:',
      'cancelled_by_admin': 'تم الإلغاء بواسطة مدير المتجر',
      'cancelled_by_rider': 'تم الإلغاء بواسطتك (السائق)',
      'order_cancelled': 'طلب ملغي',

      // Profile & Settings
      'my_profile': 'الملف الشخصي',
      'settings': 'الإعدادات',
      'branch_details': 'تفاصيل الفرع',
      'branch_name': 'اسم الفرع',
      'arabic_name': 'الاسم بالعربية',
      'address': 'العنوان',
      'arabic_address': 'العنوان بالعربية',
      'contact': 'رقم التواصل',
      'language': 'اللغة (Language)',
      'theme': 'المظهر',
      'dark_mode': 'الوضع الداكن',
      'light_mode': 'الوضع الفاتح (افتراضي)',
      'delete_account': 'حذف الحساب',
      'logout': 'تسجيل الخروج',
      'sign_out': 'تسجيل الخروج',
      'sign_out_prompt': 'هل أنت متأكد من رغبتك في تسجيل الخروج من تطبيق السائق؟',
      'delete_account_title': 'حذف الحساب؟',
      'delete_account_msg': 'طلبات حذف الحساب تتطلب موافقة مدير الفرع. هل ترغب في إرسال طلب إلغاء التنشيط؟',
      'submit_request': 'إرسال الطلب',
      'select_language': 'اختر اللغة',
      'lang_changed_toast': 'تم تغيير اللغة بنجاح إلى العربية',
      'close': 'إغلاق',
      'outlet_name': 'اسم الفرع',
      'brand': 'العلامة التجارية',
      'status': 'الحالة',
      'active_rider': 'سائق نشط',
      'inactive_rider': 'غير نشط',
      'version': 'FX Merchant Rider • الإصدار 1.0.0',
    },
  };

  String tr(String key) {
    final langCode = locale.languageCode;
    return _localizedValues[langCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

