//
//  OnboardingView.swift
//  proxy_beta
//
//  Created by Erick Verleye on 7/9/22.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct OnboardingView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    
    @State var name: String = ""
    @State var age: String = ""
    @State var relationshipStatus: String = ""
    @State var occupation: String = ""
    @State var errorText: String = ""
    @State private var isShowPhotoLibrary = false
    @State private var isShowCamera = false
    @State private var isShowMenu = false
    @State private var image = UIImage()
    
    var relationshipStatuses = ["Don't show", "Single", "In a Relationship", "Married"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    
                    Text("Please fill in some information about yourself").foregroundColor(colorScheme == .light ? Color.black : Color.white).font(.system(size: 25))
                    
                    // Main info that will always be displayed
                    HStack {
                        
                        // TODO: Editable profile photo
                        if self.session.profileInformation?.photo != nil && self.session.profileInformation?.photo != UIImage() {
                            Image(uiImage: self.session.profileInformation!.photo).fitToAspectRatio(.square).clipShape(Circle()).onTapGesture(perform: {
                                self.isShowMenu.toggle()
                            })
                        }
                        else {
                            Image(systemName: "person.crop.circle").fitToAspectRatio(.square).clipShape(Circle()).onTapGesture(perform: {
                                self.isShowMenu.toggle()
                            })
                        }
                        
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
                    }
                    .animation(.easeOut)
                    .transition(.slide)
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        alignment: .leading
                    ).padding()
                    
                    
                    Button(action: {
                        let intAge = Int(self.age)
                        
                        // Check for minimum info
                        
                        if self.session.profileInformation!.photoURL == nil {
                            self.errorText = "Please upload a profile photo before continuing"
                            return
                        }
                        
                        if !self.validName(name: self.name) {
                            self.errorText = "Please enter a valid name before continuing (no numbers or spaces)"
                            return
                        }
                        
                        if intAge ==  nil || !self.validAge(age: intAge!) {
                            self.errorText = "Please enter a valid age before continuing"
                            return
                        }
                        
                        // Check for name change
                        if self.validName(name: self.name) {
                            self.session.profileInformation!.writeNewStringValue(attribute: &self.session.profileInformation!.name, firebaseRep: UsersFields.DISPLAY_NAME, newValue: self.name)
                        }
                        
                        print(intAge, "AGE")
                        
                        // Check for age change
                        if intAge != nil && self.validAge(age: intAge!) {
                            self.session.profileInformation!.writeNewIntValue(attribute: &self.session.profileInformation!.age, firebaseRep: UsersFields.AGE, newValue: intAge)
                        }
                        
                        // Check for relationship status change
                        if self.relationshipStatus != "" {
                            self.session.profileInformation!.writeNewStringValue(attribute: &self.session.profileInformation!.relationshipStatus, firebaseRep: UsersFields.RELATIONSHIP_STATUS, newValue: self.relationshipStatus)
                        }
                        
                        // Check for occupation change
                        if self.occupation != "" {
                            self.session.profileInformation!.writeNewStringValue(attribute: &self.session.profileInformation!.occupation, firebaseRep: UsersFields.OCCUPATION, newValue: self.occupation)
                        }
                        
                        self.session.profileInformation!.minimumInfoObtained = true
                        
                    }, label: {
                        Text("Done").foregroundColor(colorScheme == .light ? Color.black : Color.white).font(.system(size: 25))
                    }).padding()
                    
                }
            }.sheet(isPresented: $isShowPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: self.$image, userCardData: self.session.profileInformation!)
            }.sheet(isPresented: $isShowCamera) {
                ImagePicker(sourceType: .camera, selectedImage: self.$image, userCardData: self.session.profileInformation!)
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
            
            if self.errorText != "" {
                ErrorView(errorText: $errorText)
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
