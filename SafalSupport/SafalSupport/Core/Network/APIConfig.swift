import Foundation

enum APIConfig {
    static let baseURL = "https://api.dev.safalirdrainmate.com"
    static let utilitiesUrl = "https://api.dev.safalutilities.com"
    static let standardizedUrl = "/api/standardized/auth/"
    static let applicationId = "safalsupport9adlch"
    static let companyId = "hemantcompanywzg6lw"
    static let authModuleURLString = APIConfig.utilitiesUrl + APIConfig.standardizedUrl +
                              APIConfig.companyId + "/" +
                              APIConfig.applicationId + "/"
    
    enum Path {
        static let appVersionCheck = "/api/application/version-check"
        static let utilities = "/api/legal-document/public"
        static let signUp = "register"
        static let signIn =  "login"
        static let forgotPassword = "reset"
        static let codeVerification = "code-verify"
        static let drainageEntries = "/api/drainage"
        static let searchByslug = "search"
        static let getUsers = "/api/user/users"
        static let userProfile = "/api/user/me"
        static let userUpdate = "/api/user/users"
        static let deleteAccount = "/api/user/user-delete"
        static let fcmToken = "/api/user/fcm"
        static let notifications = "/api/notification"
        static let resetNotificationCount = "/api/notification"
        static let notificationSettings = "/api/notification/config"
        static let getUploadUrls = "/api/upload"
        static let otpVerification = "/api/auth/verify"
        static let epicMyChartLogin = ""
        static let connectEpicMyChart = ""
        static let disconnectEpicMyChart = ""
        static let safalCalendarLogin = "/api/integration/safalcalendar/login"
        static let connectSafalCalendar = "/api/integration/safalcalendar/connect"
        static let disconnectSafalCalendar = "/api/integration/safalcalendar/disconnect"

        
        
        
        
        static let signInOrganization = "/api/auth/signin-organization"
        static let signUpOrganization = "/api/auth/sign-up-organization"
        static let meetings = "/api/calendar/meeting"
        static let meetingAuth = "/api/calendar/meeting-auth"
        static let events = "/api/calendar/event"
        static let createMeeting = "/api/calendar/meeting"
        static let uploadMeetingBanner = "/api/uploads/get-upload-urls"
        static let updateMeeting = "/api/calendar/meeting/update-auth"
        static let colors = "/api/colors"
        static let saveColors = "/api/colors"
        static let colorsConfig = "/api/colors/config"
        static let availability = "/api/calendar/availability"
        static let holidayList = "/api/calendar/holiday"
        static let safalSubscriptionsLogin = "/api/auth/login-safalsubscriptions"
        static let connectSafalSubscriptions = "/api/auth/connect-safalsubscriptions"
        static let disconnectSafalSubscriptions = "/api/auth/disconnect-safalsubscriptions"
        static let safalMyBuyLogin = "/api/auth/login-safalmybuy"
        static let connectSafalMyBuy = "/api/auth/connect-safalmybuy"
        static let disconnectSafalMyBuy = "/api/auth/disconnect-safalmybuy"
        static let reportChangeLog = "/api/change-log"
        static let safalutilitiesLogin = "/api/auth/login-safalutilities"
        static let connectsafalutilities = "/api/auth/connect-safalutilities"
        static let disconnectsafalutilities = "/api/auth/disconnect-safalutilities"
        static let contactNewsletter = "/api/contact-news-letter/public"
        static let configuration = "/api/config"
        static let userExtra = "/api/user/extra"
      
      
    }
    
    enum Header {
        static let contentType = "Content-Type"
        static let authorization = "Authorization"
        static let cookie = "Cookie"
    }
    
    enum ContentType {
        static let json = "application/json"
    }
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }
} 
