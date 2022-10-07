//
//  ProfileView.swift
//  proxy_beta
//
//  Created by Erick Verleye on 10/4/22.
//

import SwiftUI

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
    
    @Binding var editView: Bool
    
    var relationshipStatuses = ["Don't show", "Single", "In a Relationship", "Married"]
    
    var body: some View {
        GeometryReader { geometry in
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
                })
                
                // Main info that will always be displayed
                HStack {

                    // TODO: Editable profile photo
                    Image(uiImage: self.userCardData.photo).fitToAspectRatio(.square).clipShape(Circle())
                    
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
