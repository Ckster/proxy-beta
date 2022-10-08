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
                            TextField("Age:", text: $age).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).foregroundColor(colorScheme == .light ? Color.black : Color.white).font(.system(size: 25)).font(Font.headline.weight(.bold)).frame(width: geometry.size.width * 0.55, alignment: .leading)
                        
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
                
                let fileName = "\(randomString(length: 15)).jpg"
                let url = "gs://proxy-beta-436e8.appspot.com/\(fileName)"
                let publicURL = "https://storage.googleapis.com/proxy-beta-436e8.appspot.com/\(fileName)"
                let storageRef = self.parent.storage.reference(forURL: url)

                let data = image.jpegData(compressionQuality: 0.5)
                // Upload the file to the path "images/rivers.jpg"
                print("A")
                if data != nil {
                    print("B")
                    let uploadTask = storageRef.putData(data!, metadata: nil) { (metadata, error) in
                      guard let metadata = metadata else {
                        print(error, "D")
                        // Uh-oh, an error occurred!
                        return
                      }
                        
                        self.parent.userCardData.writeNewStringValue(attribute: &self.parent.userCardData.photoURL, firebaseRep: Users.fields.PHOTO_URL, newValue: publicURL)
                        self.parent.userCardData.initializePhoto()
                        
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
