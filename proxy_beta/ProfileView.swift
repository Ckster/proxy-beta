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
            if self.editView {
                EditableUserCard(userCardData: self.session.profileInformation!, editView: $editView)
            }
            else {
                VStack {
                    Button(action: {
                        self.editView = true
                    }) {
                        Image(systemName: "square.and.pencil").foregroundColor(colorScheme == .light ? Color.black : Color.white)
                    }.frame(width: geometry.size.width * 0.85, alignment: .trailing).font(.system(size: 25)).padding(.top)
                    UserCard(userCardData: self.session.profileInformation!, collapsed: false)
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
    @State private var isShowPhotoLibrary = false
    @State private var isShowCamera = false
    @State private var isShowMenu = false
    @State private var image = UIImage()
    
    @State var instagramAlert: Bool = false
    @State var instagramUser: InstagramUser? = nil
    @State var instagramApi = InstagramApi.shared
    @State var instagramSignedIn = false
    @State var instagramPresentAuth = false
    @State var testUserData = InstagramTestUser(access_token: "", user_id: 0)
    
    @Binding var editView: Bool
    
    var relationshipStatuses = ["Don't show", "Single", "In a Relationship", "Married"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    Button(action: {
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
                        
                        self.editView = false
                    }, label: {
                        Text("Done").foregroundColor(colorScheme == .light ? Color.black : Color.white).font(.system(size: 25))
                    }).padding()
                    
                    // Main info that will always be displayed
                    HStack {
                        
                        // TODO: Editable profile photo
                        Image(uiImage: self.userCardData.photo).fitToAspectRatio(.square).clipShape(Circle()).onTapGesture(perform: {
                            self.isShowMenu.toggle()
                        })
                        
                        // First name and age
                        VStack {
                            // Editable name field
                            TextField("First name:", text: $name).disableAutocorrection(true).frame(width: geometry.size.width * 0.55, alignment: .leading).foregroundColor(colorScheme == .light ? Color.black : Color.white).font(.system(size: 25))
                                .textFieldStyle(.roundedBorder)
                            
                            // Editable age field
                            // TODO: Enforce numerals only, no decimals
                            TextField("Age:", text: $age).keyboardType(.numberPad).textFieldStyle(.roundedBorder).foregroundColor(colorScheme == .light ? Color.black : Color.white).font(.system(size: 25)).font(Font.headline.weight(.bold)).frame(width: geometry.size.width * 0.55, alignment: .leading)
                        
                        }
                    }
                    
                    // Extra information
                    // TODO: Add options for removing extra info
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "heart")
                            Picker(selection: $relationshipStatus, label: Text("Relationship Status")) {
                                ForEach(relationshipStatuses, id: \.self) {
                                    Text($0).foregroundColor(colorScheme == .light ? Color.black : Color.white).font(.system(size: 20)).tag(relationshipStatuses.firstIndex(of: $0))
                                }
                            }.pickerStyle(WheelPickerStyle())
                        }
                      
                        HStack {
                            Image(systemName: "briefcase")
                            TextField("Job:", text: $occupation).textFieldStyle(.roundedBorder).foregroundColor(colorScheme == .light ? Color.black : Color.white).font(.system(size: 25)).font(Font.headline.weight(.bold)).frame(width: geometry.size.width * 0.55, alignment: .leading)
                        }
                        
                        Button(action: {
                            if self.testUserData.user_id == 0 {
                                self.instagramPresentAuth.toggle()
                              } else {
                                self.instagramApi.getInstagramUser(testUserData: self.testUserData) { (user) in
                                  self.instagramUser = user
                                    print("Instagram User", user.username)
                                }
                              }
                        }) {
                            Text("Link Instagram")
                        }
                        
                        if self.instagramUser != nil {
                            Text(self.instagramUser!.username)
                        }
                    }
                    .animation(.easeOut)
                    .transition(.slide)
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        alignment: .leading
                    ).padding()
                }
            }.sheet(isPresented: $isShowPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: self.$image, userCardData: self.userCardData)
            }.sheet(isPresented: $isShowCamera) {
                ImagePicker(sourceType: .camera, selectedImage: self.$image, userCardData: self.userCardData)
            }.sheet(isPresented: self.$instagramPresentAuth) {
                WebView(presentAuth: self.$instagramPresentAuth, testUserData: self.$testUserData, instagramApi: self.$instagramApi)
            }.onTapGesture(perform: {
                self.isShowMenu = false
            })
            if self.isShowMenu {
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
            }
        }
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
        
        let redirectURI = "https://www.google.com/"
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
       
//      print("AUTH TOKEN", authToken)
//      let headers = [
//        "content-type": "multipart/form-data; boundary=\(boundary)"
//      ]
//      let parameters = [
//        [
//          "name": "app_id",
//          "value": instagramAppID
//        ],
//        [
//          "name": "app_secret",
//          "value": app_secret
//        ],
//        [
//          "name": "grant_type",
//          "value": "authorization_code"
//        ],
//        [
//          "name": "redirect_uri",
//          "value": redirectURI
//        ],
//        [
//          "name": "code",
//          "value": authToken
//        ]
//      ]
//      var request = URLRequest(url: URL(string: BaseURL.displayApi.rawValue + Method.access_token.rawValue)!)
//      print("A", request)
//      let postData = getFormBody(parameters, boundary)
//      print("B", postData)
//      request.httpMethod = "POST"
//      request.allHTTPHeaderFields = headers
//      request.httpBody = postData
//      let session = URLSession.shared
//      print("Starting data task")
//      let dataTask = session.dataTask(with: request, completionHandler: {(data, response, error) in
//        if (error != nil) {
//          print(error!, "ERROR B")
//        } else {
//          do {
//            print("Parsing JSON")
//              print(response!)
//              print(data!)
//            let jsonData = try JSONDecoder().decode(InstagramTestUser.self, from: data!)
//            print("D", jsonData)
//            completion(jsonData)
//          } catch let error as NSError {
//            print(error, "ERROR C")
//          }
//        }
//      })
//      dataTask.resume()
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
