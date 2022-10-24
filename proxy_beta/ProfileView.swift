//
//  ProfileView.swift
//  proxy_beta
//
//  Created by Erick Verleye on 10/4/22.
//

import SwiftUI
import UIKit
import Firebase
import FirebaseStorage

struct ProfileView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    @State var editView: Bool = false
    
    var body: some View {
        
        GeometryReader {
            geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                if self.editView {
                    EditableUserCard(userCardData: self.session.profileInformation!, editView: $editView, geometry: geometry)
                }
                else {
                    VStack {
                        UserCard(userCardData: self.session.profileInformation!, collapsed: false, geometry: geometry).frame(height: geometry.size.height * 0.58, alignment: .top)
                        ActionButton(width: geometry.size.width, height: geometry.size.height, label: "Edit Profile", color: Color("Cyan")) {
                            self.editView = true
                        }.frame(height: geometry.size.height * 0.33, alignment: .bottom)
                    }
                }
            }
        }
    }
}


struct EditableUserCard: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var userCardData: UserCardData
    
    @State var name: String = ""
    @State var age: String = ""
    @State var relationshipStatus: String = ""
    @State var occupation: String = ""
    
    @State var instagramAlert: Bool = false
    @State var instagramUser: InstagramUser? = nil
    @State var instagramSignedIn = false
    @State var instagramPresentAuth = false
    
    @State var isShowImageMenu: Bool = false
    @State private var isShowPhotoLibrary = false
    @State private var isShowCamera = false
    
    @Binding var editView: Bool
    let geometry: GeometryProxy
    
    var body: some View {
            VStack {
                ScrollView {
                    // Main info that will always be displayed
                    EditableCardMain(userCardData: self.userCardData, name: $name, age: $age, isShowImageMenu: $isShowImageMenu, isShowPhotoLibrary: $isShowPhotoLibrary, isShowCamera: $isShowCamera, geometry: geometry).frame(height: geometry.size.height * 0.45, alignment: .bottom)
                    
                    // Extra information
                    EditableCardExtra(userCardData: self.userCardData, relationshipStatus: $relationshipStatus, occupation: $occupation, instagramPresentAuth: $instagramPresentAuth, instagramUser: $instagramUser, geometry: geometry).frame(height: geometry.size.height * 0.45, alignment: .top)
                }
                
                ActionButton(width: geometry.size.width, height: geometry.size.height, label: "Done", color: Color("Cyan")) {
                    let intAge = Int(self.age)
                    
                    // Check for name change
                    if self.validName(name: self.name) && self.name != self.userCardData.name {
                        self.userCardData.writeNewStringValue(attribute: &self.userCardData.name, firebaseRep: UsersFields.DISPLAY_NAME, newValue: self.name)
                    }
                    
                    // Check for age change
                    if intAge != nil && self.validAge(age: intAge!) && intAge! != self.userCardData.age! {
                        self.userCardData.writeNewIntValue(attribute: &self.userCardData.age, firebaseRep: UsersFields.AGE, newValue: intAge)
                    }
                    
                    // Check for relationship status change
                    if self.relationshipStatus != "" && self.relationshipStatus != self.userCardData.relationshipStatus {
                        self.userCardData.writeNewStringValue(attribute: &self.userCardData.relationshipStatus, firebaseRep: UsersFields.RELATIONSHIP_STATUS, newValue: self.relationshipStatus)
                    }
                    
                    // Check for occupation change
                    if self.occupation != "" && self.occupation != self.userCardData.occupation {
                        self.userCardData.writeNewStringValue(attribute: &self.userCardData.occupation, firebaseRep: UsersFields.OCCUPATION, newValue: self.occupation)
                    }
                    
                    if self.instagramUser != nil && self.instagramUser!.username != self.userCardData.instagramUsername {
                        self.userCardData.writeNewStringValue(attribute: &self.userCardData.instagramUsername, firebaseRep: UsersFields.INSTAGRAM_USERNAME, newValue: self.instagramUser!.username)
                    }
                    
                    self.editView = false
                }.frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .center)
            }
        
        .if(self.isShowImageMenu) { view in
            // Blur the background when the completion animation is showing
            view.blur(radius: CGFloat(10))
        }.disabled(self.isShowImageMenu)
        .onTapGesture {
            self.endEditing()
        }
        
        if self.isShowImageMenu {
            ImageMenu(isShowPhotoLibrary: $isShowPhotoLibrary, isShowCamera: $isShowCamera, isShowImageMenu: $isShowImageMenu, geometry: geometry)
        }
    }
    
    private func endEditing() {
            UIApplication.shared.endEditing()
        }
    
    func validName(name: String) -> Bool {
        let characterset = CharacterSet(charactersIn:
           "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        )
        
        return !name.isEmpty && !name.contains(" ") && name.rangeOfCharacter(from: characterset.inverted) == nil
    }
    
    func validAge(age: Int) -> Bool {
        return age < 18 || age < 100
    }
    
}


struct ImageMenu: View {
    @Binding var isShowPhotoLibrary: Bool
    @Binding var isShowCamera: Bool
    @Binding var isShowImageMenu: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                Text("Photo library")
                    .font(.headline)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 50)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.horizontal)
            .onTapGesture(perform: {
                self.isShowPhotoLibrary = true
            })
            
            HStack {
                Image(systemName: "camera")
                    .font(.system(size: 20))
                
                Text("Camera")
                    .font(.headline)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 50)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.horizontal)
            .onTapGesture(perform: {
                self.isShowCamera = true
            })
        }
        .frame(width: geometry.size.width, height: geometry.size.height * 0.95, alignment: .bottom)
        .animation(.easeInOut)
        .transition(.move(edge: .bottom))
        .contentShape(Rectangle())
        .onTapGesture {
            self.isShowImageMenu = false
        }
    }
}


struct EditableCardMain: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var userCardData: UserCardData
    
    @Binding var name: String
    @Binding var age: String
    @Binding var isShowImageMenu: Bool
    @Binding var isShowPhotoLibrary: Bool
    @Binding var isShowCamera: Bool
        
    @State private var image = UIImage()
    
    let geometry: GeometryProxy
    
    var body: some View {
        VStack {
            Image(uiImage: self.userCardData.photo).fitToAspectRatio(.square).clipShape(Circle()).onTapGesture(perform: {
                self.isShowImageMenu.toggle()
            })
            
            VStack(alignment: .leading) {
                // First name and age
                
                // Editable name field
                //Text("First name").frame(width: geometry.size.width, alignment: .leading).foregroundColor(.white)
                NeumorphicStyleTextField(textField: TextField("", text: $name), imageName: nil, textBinding: $name, placeholderText: self.userCardData.name!, autoCorrect: false).frame(width: geometry.size.width * 0.5)
                
                // Editable age field
                // TODO: Enforce numerals only, no decimals
                //Text("Age").frame(width: geometry.size.width, alignment: .leading).foregroundColor(.white)
                // TODO: Put a number picker in here instead and just show the age as a button
                TextField(String(self.userCardData.age!), text: $age).keyboardType(.numberPad).textFieldStyle(.roundedBorder).font(.system(size: 25)).font(Font.headline.weight(.bold)).frame(width: geometry.size.width * 0.55, alignment: .leading)
                //NeumorphicStyleTextField(textField: <#T##TextField<Text>#>, imageName: <#T##String?#>, textBinding: <#T##Binding<String>#>, placeholderText: <#T##String#>)
            }.padding(.leading)
        }.sheet(isPresented: $isShowPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: self.$image, userCardData: self.userCardData)
        }.sheet(isPresented: $isShowCamera) {
            ImagePicker(sourceType: .camera, selectedImage: self.$image, userCardData: self.userCardData)
        }
    }
}

struct EditableCardExtra: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var userCardData: UserCardData
    @Binding var relationshipStatus: String
    @Binding var occupation: String
    @Binding var instagramPresentAuth: Bool
    @Binding var instagramUser: InstagramUser?
    let geometry: GeometryProxy
    let relationshipStatuses = ["Don't show", "Single", "In a Relationship", "Married"]
    
    @State var instagramApi = InstagramApi.shared
    
    var body: some View {
        // TODO: Add options for removing extra info
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "heart").foregroundColor(.white)
                Picker(selection: $relationshipStatus, label: Text("Relationship Status")) {
                    ForEach(relationshipStatuses, id: \.self) {
                        Text($0).foregroundColor(.white).font(.system(size: 20)).tag(relationshipStatuses.firstIndex(of: $0))
                    }
                }.pickerStyle(WheelPickerStyle())
            }
            
            NeumorphicStyleTextField(textField: TextField("", text: $occupation), imageName: "briefcase", textBinding: $occupation, placeholderText: self.userCardData.occupation ?? "Job").frame(width: geometry.size.width * 0.5).padding(.leading).padding(.bottom)
                    
            Button(action: {
                self.instagramPresentAuth.toggle()
            }) {
                HStack {
                    Image("instagram_logo").resizable().frame(width: geometry.size.width * 0.10, height: geometry.size.width * 0.10)
                    
                    if self.instagramUser != nil {
                        Text("\(self.instagramUser!.username)").foregroundColor(Color("Cyan"))
                    }
                    else {
                        if self.userCardData.instagramUsername != nil {
                            Text("\(self.userCardData.instagramUsername!)").foregroundColor(Color("Cyan"))
                        }
                        else {
                            Text("Link Instagram").foregroundColor(Color("Cyan"))
                        }
                    }
                }.padding(.leading)
            }
        }.sheet(isPresented: self.$instagramPresentAuth) {
            WebView(presentAuth: self.$instagramPresentAuth, InstagramUserData: self.$instagramUser, instagramApi: self.$instagramApi)
        }
    }
}



extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Binding var selectedImage: UIImage
    @ObservedObject var userCardData: UserCardData
    @Environment(\.presentationMode) private var presentationMode
    let storage = Storage.storage()
 
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
 
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = false
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
 
        return imagePicker
    }
 
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
 
    }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
     
        var parent: ImagePicker
     
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
     
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
     
            if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                parent.selectedImage = image
                self.parent.userCardData.photo = image
                
                let fileName = "\(randomString(length: 15)).jpg"
                let url = "gs://proxy-beta-436e8.appspot.com/\(fileName)"
                let publicURL = "https://storage.googleapis.com/proxy-beta-436e8.appspot.com/\(fileName)"
                let storageRef = self.parent.storage.reference(forURL: url)
                let data = image.jpegData(compressionQuality: 0.9)
                if data != nil {
                    let uploadTask = storageRef.putData(data!, metadata: nil) { (metadata, error) in
                      guard let metadata = metadata else {
                        return
                      }
                        self.parent.userCardData.writeNewStringValue(attribute: &self.parent.userCardData.photoURL, firebaseRep: Users.fields.PHOTO_URL, newValue: publicURL)
                    }
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
}


func randomString(length: Int) -> String {
  let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  return String((0..<length).map{ _ in letters.randomElement()! })
}


class InstagramApi {
  static let shared = InstagramApi()
  private let instagramAppID = "891837165115758"
  private let redirectURIURLEncoded = "https%3A%2F%2Fwww.google.com%2F"
  private let redirectURI = "https://www.google.com/"
  private let app_secret = "583a2c7d965929b6222ef1b8f972b0d6"
  private let boundary = "boundary=\(NSUUID().uuidString)"
  private init () {}
    
    
  private enum BaseURL: String {
      case displayApi = "https://api.instagram.com/"
      case graphApi = "https://graph.instagram.com/"
  }
    
  private enum Method: String {
      case authorize = "oauth/authorize"
      case access_token = "oauth/access_token"
  }
    
  func authorizeApp(completion: @escaping (_ url: URL?) -> Void ) {
      let urlString = "\(BaseURL.displayApi.rawValue)\(Method.authorize.rawValue)?app_id=\(instagramAppID)&redirect_uri=\(redirectURIURLEncoded)&scope=user_profile&response_type=code"
      let request = URLRequest(url: URL(string: urlString)!)
      let session = URLSession.shared
      let task = session.dataTask(with: request, completionHandler: {  data, response, error in
        if let response = response {
          print("RESPONSE", response)
          completion(response.url)
        }
      })
      task.resume()
    }
    
    private func getTokenFromCallbackURL(request: URLRequest) -> String? {
      let requestURLString = (request.url?.absoluteString)! as String
      print(requestURLString, "\(redirectURI)?code=")
      if requestURLString.starts(with: "\(redirectURI)?code=") {
        print("Response uri:", requestURLString)
        if let range = requestURLString.range(of: "\(redirectURI)?code=") {
            return String(requestURLString[range.upperBound...].dropLast(2))
        }
          else {
              print("NO RANGE")
          }
      }
        else {
            print("NO STARTS WITH")
        }
      return nil
    }
    
    private func getFormBody(_ parameters: [[String : String]], _ boundary: String) -> Data {
      var body = ""
      let error: NSError? = nil
      for param in parameters {
        let paramName = param["name"]!
        body += " — \(boundary)\r\n"
        body += "Content-Disposition:form-data; name=\"\(paramName)\""
        if let filename = param["fileName"] {
          let contentType = param["content-type"]!
          var fileContent: String = ""
          do {
            fileContent = try String(contentsOfFile: filename, encoding: String.Encoding.utf8)
          }catch {
            print("C", error)
          }
          if (error != nil) {
            print("D", error!)
          }
          body += "; filename=\"\(filename)\"\r\n"
          body += "Content-Type: \(contentType)\r\n\r\n"
          body += fileContent
        } else if let paramValue = param["value"] {
          body += "\r\n\r\n\(paramValue)"
        }
      }
      print("JSON DATA", body)
      return body.data(using: .utf8)!
    }
    
    func getTestUserIDAndToken(request: URLRequest, completion: @escaping (InstagramTestUser) -> Void){
      guard let authToken = getTokenFromCallbackURL(request: request)   else {
        print("failed callback")
        return
      }
            let redirectURI = self.redirectURI
            let clientID = self.instagramAppID
            let clientSecret = self.app_secret
            let code = authToken

            let urlString = "https://api.instagram.com/oauth/access_token"
            let url = NSURL(string: urlString)!
            let paramString  = "client_id=\(clientID)&client_secret=\(clientSecret)&grant_type=authorization_code&redirect_uri=\(redirectURI)&code=\(code)&scope=basic+public_content"

            let request = NSMutableURLRequest(url: url as URL)
            request.httpMethod = "POST"
            request.httpBody = paramString.data(using: String.Encoding.utf8)!

            let task =  URLSession.shared.dataTask(with: request as URLRequest)  { (data, response, error) in
                do {
                    if let jsonData = data {
                        if let jsonDataDict  = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
                            NSLog("Received data:\n\(jsonDataDict))")
                            completion(InstagramTestUser(access_token: jsonDataDict["access_token"] as? String ?? "", user_id: jsonDataDict["user_id"] as? Int ?? 0))
                        }
                    }
                } catch let err as NSError {
                    print(err.debugDescription)
                }
            }

            task.resume()
    }
    
    func getInstagramUser(testUserData: InstagramTestUser, completion: @escaping (InstagramUser) -> Void) {
        print("ACESS TOKEN", testUserData.access_token)
      let urlString = "\(BaseURL.graphApi.rawValue)\(testUserData.user_id)?fields=id,username&access_token=\(testUserData.access_token)"
      let request = URLRequest(url: URL(string: urlString)!)
      let session = URLSession.shared
      let dataTask = session.dataTask(with: request, completionHandler: {(data, response, error) in
        if (error != nil) {
          print(error!, "ERROR A")
        } else {
          let httpResponse = response as? HTTPURLResponse
          print(httpResponse!)
        }
        do { let jsonData = try JSONDecoder().decode(InstagramUser.self, from: data!)
          completion(jsonData)
        }catch let error as NSError {
          print(error)
        }
      })
      dataTask.resume()
    }
    
}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


extension Color {
    static let lightShadow = Color(red: 255 / 255, green: 255 / 255, blue: 255 / 255)
    static let darkShadow = Color(red: 163 / 255, green: 177 / 255, blue: 198 / 255)
    static let background = Color(red: 224 / 255, green: 229 / 255, blue: 236 / 255)
    static let neumorphictextColor = Color(red: 132 / 255, green: 132 / 255, blue: 132 / 255)
}


struct NeumorphicStyleTextField: View {
    var textField: TextField<Text>
    var imageName: String?
    @Binding var textBinding: String
    let placeholderText: String
    var autoCorrect: Bool
    
    init(textField: TextField<Text>, imageName: String?, textBinding: Binding<String>, placeholderText: String, autoCorrect: Bool = true) {
        self.textField = textField
        self.imageName = imageName
        _textBinding = textBinding
        self.placeholderText = placeholderText
        self.autoCorrect = autoCorrect
    }
    
    var body: some View {
        HStack {
            if imageName != nil {
                Image(systemName: imageName!)
                    .foregroundColor(.darkShadow)
            }
            textField.placeholder(when: textBinding.isEmpty) {Text(self.placeholderText).foregroundColor(.gray)}.autocorrectionDisabled(!autoCorrect)
            }
            .padding()
            .foregroundColor(.white)
            .background(Color.black)
            .cornerRadius(6)
            .shadow(color: Color("Cyan"), radius: 3, x: 2, y: 2)
            .shadow(color: Color("Cyan"), radius: 3, x: -2, y: -2)

        }
}
