# Odoo Integration Guide

This document explains how to integrate your HR app with Odoo using XML-RPC.

## 🚀 **Quick Setup**

### 1. **Update Configuration**
Edit `lib/config/odoo_config.dart` and update these values:

```dart
static const String baseUrl = 'https://your-odoo-server.com'; // Your Odoo server URL
static const String database = 'your_database_name'; // Your database name
```

### 2. **Odoo Server Requirements**
- Odoo 12.0 or higher
- XML-RPC enabled
- HR module installed
- User with appropriate permissions

## 🔧 **Configuration Details**

### **Base URL Format**
- **Local Development**: `http://localhost:8069`
- **Production**: `https://yourdomain.com`
- **Custom Port**: `http://localhost:8080`

### **Database Name**
- Usually found in Odoo's database selector
- Common names: `odoo`, `production`, `test`

## 📱 **Features Available**

### **Authentication**
- ✅ Login with Odoo credentials
- ✅ Session management
- ✅ Automatic logout

### **HR Operations**
- ✅ Employee information retrieval
- ✅ Attendance check-in/out
- ✅ Leave request viewing
- ✅ Expense management
- ✅ Payslip access
- ✅ Contract information

## 🔐 **User Permissions Required**

Your Odoo user needs access to these models:

```python
# In Odoo, ensure user has access to:
- hr.employee (read)
- hr.attendance (read, write, create)
- hr.leave (read)
- hr.expense (read)
- hr.payslip (read)
- hr.contract (read)
- res.users (read)
```

## 🧪 **Testing the Integration**

### **1. Test Connection**
```bash
flutter run -d chrome
```
- Use your Odoo credentials
- Check console for connection logs

### **2. Test Attendance**
- Login to the app
- Try check-in/check-out
- Verify records appear in Odoo

### **3. Check Logs**
Monitor the console for:
- Authentication success/failure
- RPC call results
- Error messages

## 🐛 **Troubleshooting**

### **Common Issues**

#### **1. Connection Refused**
```
Error: Connection refused
```
**Solution**: Check if Odoo server is running and accessible

#### **2. Authentication Failed**
```
Error: Authentication failed
```
**Solution**: Verify username, password, and database name

#### **3. Permission Denied**
```
Error: Access denied
```
**Solution**: Check user permissions in Odoo

#### **4. Model Not Found**
```
Error: Model 'hr.employee' not found
```
**Solution**: Ensure HR module is installed

### **Debug Steps**

1. **Check Network**
   ```bash
   curl -X POST https://your-odoo-server.com/xmlrpc/2/common
   ```

2. **Verify Odoo Status**
   - Check Odoo logs
   - Verify XML-RPC is enabled
   - Test with Odoo's built-in XML-RPC tester

3. **Check App Logs**
   - Monitor Flutter console
   - Look for HTTP response codes
   - Check XML response parsing

## 📊 **Data Flow**

```
Flutter App → HTTP Request → Odoo XML-RPC → Database → Response → Flutter App
```

### **Example Flow: Check-In**
1. User taps "Check In"
2. App calls `HrService.checkIn()`
3. Service creates XML-RPC request
4. Odoo creates `hr.attendance` record
5. Success response returned to app
6. UI updates to show checked-in state

## 🔒 **Security Considerations**

### **HTTPS Required**
- Always use HTTPS in production
- Never send credentials over HTTP

### **Session Management**
- Sessions automatically expire
- Credentials not stored locally
- Automatic logout on app close

### **Input Validation**
- All user inputs validated
- SQL injection protection via Odoo's ORM
- XSS protection in place

## 📈 **Performance Tips**

### **Optimization**
- Use appropriate page sizes
- Implement caching for static data
- Batch operations when possible

### **Monitoring**
- Track API response times
- Monitor memory usage
- Log performance metrics

## 🚀 **Production Deployment**

### **Checklist**
- [ ] HTTPS enabled
- [ ] Firewall configured
- [ ] Rate limiting set
- [ ] Error logging enabled
- [ ] Backup strategy in place

### **Environment Variables**
Consider using environment variables for sensitive data:

```dart
// In production, use environment variables
static const String baseUrl = String.fromEnvironment('ODOO_URL');
static const String database = String.fromEnvironment('ODOO_DB');
```

## 📚 **Additional Resources**

- [Odoo XML-RPC Documentation](https://www.odoo.com/documentation/16.0/developer/reference/external_api.html)
- [Flutter HTTP Package](https://pub.dev/packages/http)
- [Odoo HR Module Documentation](https://www.odoo.com/documentation/16.0/applications/hr.html)

## 🆘 **Support**

If you encounter issues:

1. Check this troubleshooting guide
2. Review Odoo server logs
3. Verify network connectivity
4. Test with Odoo's built-in tools
5. Check user permissions

## 📝 **Changelog**

- **v1.0**: Initial Odoo integration
- **v1.1**: Added HR service layer
- **v1.2**: Enhanced error handling
- **v1.3**: Added attendance management 