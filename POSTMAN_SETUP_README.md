# HR App Odoo - Postman API Collection Setup Guide

This guide explains how to set up and use the Postman collection to test all the HR App Odoo APIs.

## 📦 Files Included

1. **`HR_App_Odoo_API_Collection.postman_collection.json`** - Main API collection
2. **`HR_App_Odoo_Environment.postman_environment.json`** - Environment variables
3. **`POSTMAN_SETUP_README.md`** - This setup guide

## 🚀 Quick Setup

### Step 1: Import Collection
1. Open Postman
2. Click **Import** button
3. Drag and drop `HR_App_Odoo_API_Collection.postman_collection.json`
4. The collection will appear in your collections list

### Step 2: Import Environment
1. In Postman, click **Import** again
2. Drag and drop `HR_App_Odoo_Environment.postman_environment.json`
3. Select the environment from the dropdown in the top-right corner

### Step 3: Update Credentials
1. Click the environment dropdown (top-right)
2. Click the edit icon (pencil)
3. Update these values:
   - `username`: Your Odoo username
   - `password`: Your Odoo password
   - `baseUrl`: Your Odoo server URL
   - `database`: Your Odoo database name

## 🔐 Authentication Flow

The collection follows this authentication sequence:

### 1. Get Web Session
- **Endpoint**: `GET {{baseUrl}}/web`
- **Purpose**: Gets initial session cookie
- **Response**: Look for `session_id` in cookies

### 2. Authenticate User
- **Endpoint**: `POST {{baseUrl}}/web/session/authenticate`
- **Purpose**: Authenticates user with credentials
- **Response**: Contains `uid` (user ID)

### 3. Update Environment Variables
After successful authentication:
1. Copy the `uid` from response to `userId` environment variable
2. Copy the `session_id` cookie to `sessionId` environment variable

## 📱 API Categories

### 🔐 Authentication
- Get Web Session
- Authenticate User
- Test Connection

### 👤 Employee Management
- Get Current Employee
- Get All Employees

### ⏰ Attendance Management
- Check In Employee
- Check Out Employee
- Get Employee Attendance
- Get Current Attendance

### 💰 Expense Management
- Create Expense
- Get Employee Expenses

### 📊 Payslip Management
- Get Employee Payslips
- Get All Payslips

### 📋 Contract Management
- Get Employee Contracts
- Get All Contracts

### 🏖️ Leave Management
- Get Employee Leaves
- Get Holiday Status Types

### 🔍 System Information
- Get User Permissions
- Get Available Models

## 🧪 Testing Workflow

### 1. Test Connection
Start with "Test Connection" to verify server accessibility.

### 2. Authentication
1. Run "Get Web Session"
2. Run "Authenticate User"
3. Update environment variables with response data

### 3. Test HR Operations
Once authenticated, test various HR operations:
- Employee information
- Attendance tracking
- Expense creation
- Payslip access
- Contract details
- Leave management

## 🔧 Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `baseUrl` | Odoo server URL | `https://your-server.com` |
| `database` | Database name | `your_database` |
| `username` | Odoo username | `admin@admin.com` |
| `password` | Odoo password | `your_password` |
| `userId` | Authenticated user ID | `1` |
| `sessionId` | Session cookie | `abc123...` |
| `employeeId` | Employee record ID | `2` |
| `attendanceId` | Attendance record ID | `15` |
| `checkInTime` | Check-in timestamp | `2024-01-01 09:00:00` |
| `checkOutTime` | Check-out timestamp | `2024-01-01 17:00:00` |
| `startDate` | Date range start | `2024-01-01 00:00:00` |
| `endDate` | Date range end | `2024-01-31 23:59:59` |
| `expenseName` | Expense description | `Office Supplies` |
| `expenseDate` | Expense date | `2024-01-01` |
| `totalAmount` | Expense amount | `100.00` |
| `taxAmount` | Tax amount | `10.00` |
| `generateTimestamp` | Auto-generate timestamps | `true` |

## 📝 Request Examples

### Authentication Request
```json
{
  "jsonrpc": "2.0",
  "method": "call",
  "params": {
    "db": "{{database}}",
    "login": "{{username}}",
    "password": "{{password}}"
  }
}
```

### Employee Search Request
```json
{
  "jsonrpc": "2.0",
  "method": "call",
  "params": {
    "service": "object",
    "method": "execute_kw",
    "args": [
      "{{database}}",
      "{{userId}}",
      "{{password}}",
      "hr.employee",
      "search_read",
      [["user_id", "=", "{{userId}}"]],
      ["id", "name", "work_email"],
      0,
      1,
      "id desc",
      {}
    ]
  }
}
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Authentication Failed
- Verify username/password
- Check database name
- Ensure server is accessible

#### 2. Permission Denied
- Check user permissions in Odoo
- Verify HR modules are installed
- Contact Odoo administrator

#### 3. Model Not Found
- Ensure HR module is installed
- Check model names are correct
- Verify user has access to models

#### 4. Session Expired
- Re-run authentication flow
- Update session variables
- Check server session timeout

### Debug Steps

1. **Check Response Status**: Look for HTTP status codes
2. **Review Response Body**: Check for error messages
3. **Verify Variables**: Ensure environment variables are set
4. **Check Headers**: Verify required headers are present
5. **Test Connection**: Ensure server is reachable

## 📊 Response Examples

### Successful Authentication
```json
{
  "jsonrpc": "2.0",
  "id": null,
  "result": {
    "uid": 1,
    "user_context": {
      "lang": "en_US",
      "tz": "UTC"
    }
  }
}
```

### Employee Data
```json
{
  "jsonrpc": "2.0",
  "id": null,
  "result": [
    {
      "id": 2,
      "name": "John Doe",
      "work_email": "john@example.com",
      "job_title": "Software Developer"
    }
  ]
}
```

### Error Response
```json
{
  "jsonrpc": "2.0",
  "id": null,
  "error": {
    "code": 200,
    "message": "Odoo Server Error",
    "data": {
      "name": "AccessError",
      "debug": "Access denied"
    }
  }
}
```

## 🔄 Automation

### Pre-request Scripts
The collection includes pre-request scripts that:
- Auto-generate timestamps
- Set dynamic variables
- Handle authentication tokens

### Test Scripts
Add test scripts to:
- Validate responses
- Extract data for subsequent requests
- Handle errors gracefully

## 📱 Mobile Testing

### Postman Mobile App
1. Install Postman mobile app
2. Sync your collection
3. Test APIs on mobile devices
4. Perfect for field testing

### Environment Sync
- Use Postman cloud to sync environments
- Share collections with team members
- Maintain consistent testing across devices

## 🚀 Production Deployment

### Security Considerations
- Use environment variables for sensitive data
- Never commit credentials to version control
- Use HTTPS in production
- Implement proper authentication

### Monitoring
- Set up response time monitoring
- Log API errors and failures
- Monitor authentication success rates
- Track API usage patterns

## 📚 Additional Resources

- [Odoo XML-RPC Documentation](https://www.odoo.com/documentation/16.0/developer/reference/external_api.html)
- [Postman Learning Center](https://learning.postman.com/)
- [Flutter HTTP Package](https://pub.dev/packages/http)
- [Odoo HR Module](https://www.odoo.com/documentation/16.0/applications/hr.html)

## 🆘 Support

If you encounter issues:

1. Check this troubleshooting guide
2. Verify Odoo server configuration
3. Test with Odoo's built-in tools
4. Check user permissions
5. Review server logs

## 📝 Changelog

- **v1.0**: Initial Postman collection
- **v1.1**: Added environment variables
- **v1.2**: Enhanced authentication flow
- **v1.3**: Added comprehensive testing examples

---

**Happy Testing! 🎉**

Use this collection to thoroughly test your HR App Odoo integration and ensure all APIs work correctly before deploying to production.

