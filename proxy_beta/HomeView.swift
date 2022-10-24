//
//  HomeView.swift
//  proxy_beta
//
//  Created by Erick Verleye on 7/9/22.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import GeoFire
import CoreLocation


let radiusInM: Double = 10  // TODO: Make this smaller eventually


struct HomeView: View {
    var locationManager = UserLocation.shared
    var db = Firestore.firestore()
    @EnvironmentObject var session: SessionStore
    @ObservedObject var closeUserData: CloseUserData
    
    var body: some View {
        GeometryReader {
            geometry in
            if !self.locationManager.searchEnabled {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ActionButton(width: geometry.size.width, height: geometry.size.height, label: "Go Live", color: Color("Cyan")) {
                        // Add the user to active pool
                        
                        // TODO: Check if user's location permissions are adequete here
                        
                        // This starts a request and the result is sent to UserLocation didUpdateLocations function,
                        // or in the case of an error the UserLocation didFinishWithError function
                        locationManager.locationManager.requestLocation()
                        self.closeUserData.loading = true
                        self.locationManager.searchEnabled = true
                    }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                }
            }
            else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if self.closeUserData.loading {
                        LottieView(name: "82418-searching-animation")
                    }
                    
                    else {
                        VStack {
                            if self.closeUserData.closeUsers.count == 0 {
                                NoUsersView(closeUserData: self.closeUserData).frame(height: geometry.size.height * 0.85)
                            }
                            else {
                                CloseUsersListView(closestUserData: self.closeUserData).frame(width: geometry.size.width, height: geometry.size.height * 0.85, alignment: .center).padding(.top)
                            }
                            
                            ActionButton(width: geometry.size.width, height: geometry.size.height, label: "Don't show me", color: Color("Cyan")) {
                                let document = self.db.document("\(Users.name)/\(self.session.user.uid!)")
                                document.updateData([
                                    UsersFields.GEOHASH: nil,
                                    UsersFields.LATITUDE: nil,
                                    UsersFields.LONGITUDE: nil
                                ])
                                self.locationManager.searchEnabled = false
                                self.locationManager.removeRegisteredRegions()
                            }
                        }
                    }
                }
            }
        }
        // Once the user's location is received this will be called and we can start getting closest users if there is no error
        .onReceive(locationManager.$userLocation, perform: { newLocation in
            print("RECEIVED NEW LOCATION MN")
            if newLocation != nil {
                // Get rid of all existing geofences
                self.locationManager.removeRegisteredRegions()
                
                // Register the new region so that when the user leaves the area they are in they are no longer findable by others
                self.locationManager.registerRegionAtLocation(center: newLocation!, radius: radiusInM, uid: self.session.user.uid!)
                
                print("RECEIVED NEW LOCATION")
                // When this is done the closestUsers list will be updated and we can show the results
                self.closeUserData.findClosestUsers(userLocation: newLocation!)
                
                // Don't need to wait for this to finish really ... updates the user's geohash and shows that they are broadcasting themselves
                self.activateUserDocument(userLocation: newLocation!)
            }
            else {
                // TODO: Show an error here
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification), perform: { _ in
            // This is just to refresh the list of nearby users
            if self.locationManager.searchEnabled && self.locationManager.userLocation != nil {
                self.closeUserData.findClosestUsers(userLocation: self.locationManager.userLocation!)
            }
        })
    }
    
    func activateUserDocument(userLocation: CLLocationCoordinate2D) {
        print("ACTIVATING USER DOC")
        let hash = GFUtils.geoHash(forLocation: userLocation)

        // Add the hash and the lat/lng to the document. We will use the hash
        // for queries and the lat/lng for distance comparisons.
        let documentData: [String: Any] = [
            Users.fields.GEOHASH: hash,
            Users.fields.LATITUDE: userLocation.latitude,
            Users.fields.LONGITUDE: userLocation.longitude
        ]

        let userRef = db.collection(Users.name).document(self.session.user.uid ?? "")
        userRef.updateData(documentData) { error in
            // ...
        }
    }
}

struct NoUsersView: View {
    @ObservedObject var closeUserData: CloseUserData
    var locationManager = UserLocation.shared
        
    var body: some View {
        ScrollView {
            PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                // Add the user to active pool
                
                // TODO: Check if user's location permissions are adequete here
                
                // This starts a request and the result is sent to UserLocation didUpdateLocations function,
                // or in the case of an error the UserLocation didFinishWithError function
                locationManager.locationManager.requestLocation()
                self.closeUserData.loading = true
                self.locationManager.searchEnabled = true
            }
            Text("No users nearby!").font(.system(size: 25)).multilineTextAlignment(.center).offset(y: 25)
        }.coordinateSpace(name: "pullToRefresh")
    }
}

class CloseUserData: ObservableObject {
    var uid: String?
    @Published var closeUsers: [UserCardData] = []
    @Published var loading: Bool = true
    var db = Firestore.firestore()
    
    init (uid: String?) {
        self.uid = uid
    }
    
    func findClosestUsers(userLocation: CLLocationCoordinate2D) {
        print("FINDING CLOSEST USERS")

        // Find users within 500m of user
        
        var last: Bool = false

        // Each item in 'bounds' represents a startAt/endAt pair. We have to issue
        // a separate query for each pair. There can be up to 9 pairs of bounds
        // depending on overlap, but in most cases there are 4.
        let queryBounds = GFUtils.queryBounds(forLocation: userLocation,
                                              withRadius: radiusInM)
        let queries = queryBounds.map { bound -> Query in
            return db.collection(Users.name)
                .order(by: Users.fields.GEOHASH)
                .start(at: [bound.startValue])
                .end(at: [bound.endValue])
        }

        var newUserCards: [UserCardData] = []
        // Collect all the query results together into a single list
        func getDocumentsCompletion(snapshot: QuerySnapshot?, error: Error?) -> () {
            guard let documents = snapshot?.documents else {
                print("Unable to fetch snapshot data. \(String(describing: error))")
                return
            }

            for document in documents {
                
                // Make sure to skip over the user making the query
                if document.documentID != self.uid ?? "" {
                    let lat = document.data()[Users.fields.LATITUDE] as? Double ?? 0
                    let lng = document.data()[Users.fields.LONGITUDE] as? Double ?? 0
                    let coordinates = CLLocation(latitude: lat, longitude: lng)
                    let centerPoint = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

                    // We have to filter out a few false positives due to GeoHash accuracy, but
                    // most will match
                    let distance = GFUtils.distance(from: centerPoint, to: coordinates)
                    if distance <= radiusInM {
                        newUserCards.append(UserCardData(uid: document.documentID, name: document.get(Users.fields.DISPLAY_NAME) as? String, age: document.get(Users.fields.AGE) as? Int, photoURL: document.get(Users.fields.PHOTO_URL) as? String, relationshipStatus: document.get(Users.fields.RELATIONSHIP_STATUS) as? String, occupation: document.get(Users.fields.OCCUPATION) as? String, instagramUsername: document.get(Users.fields.INSTAGRAM_USERNAME) as? String))
                    }
                    if last && document == documents.last {
                        print("Updating closest users")
                        self.closeUsers = newUserCards

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.loading = false
                        }
                        
                    }
                }
                else {
                    if last && document == documents.last {
                        self.closeUsers = newUserCards
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.loading = false
                        }
                    }
                }
            }
            
            if documents.count == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.loading = false
                }
            }
        }

        for query in queries {
            last = query == queries.last
            query.getDocuments(completion: getDocumentsCompletion)
        }
        
        if queries.count == 0 {
            self.loading = false
        }
        
    }
    
    
}

class UserCardData: Hashable, ObservableObject {
    private var db = Firestore.firestore()
    
    let uid: String
    
    @Published var photo: UIImage = UIImage()
    @Published var minimumInfoObtained: Bool?
    
    var name: String?
    var age: Int?
    var photoURL: String?
    var relationshipStatus: String?
    var occupation: String?
    var instagramUsername: String?
    
    init (uid: String, name: String?, age: Int?, photoURL: String?, relationshipStatus: String?, occupation: String?, instagramUsername: String?) {
        self.uid = uid
        self.name = name
        self.age = age
        self.photoURL = photoURL
        self.initializePhoto()
        self.relationshipStatus = relationshipStatus
        self.occupation = occupation
        self.instagramUsername = instagramUsername
    }
    
    func initializePhoto() {
        if self.photoURL != nil {
            let feedURL: URL? = URL(string: self.photoURL!)
            if feedURL != nil {
                let task = URLSession.shared.dataTask(with: feedURL!) { data, response, error in
                    if error == nil && data != nil {
                        print("UPDATING IMAGE")
                        DispatchQueue.main.async {
                            self.photo = UIImage(data: data!)!
                        }
                    }
                }
                task.resume()
            }
        }
    }
    
    func equals(crossing: UserCardData) -> Bool {
        if crossing.uid == self.uid {
            return true
        }
        else {
            return false
        }
    }
    
    static func ==(lhs:UserCardData, rhs:UserCardData) -> Bool { // Implement Equatable
        return lhs.uid == rhs.uid
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.uid)
    }
    
    func calcMinimumInfoObtained() {
        let test = self.name != nil && self.age != nil && self.photoURL != nil
        self.minimumInfoObtained = test
    }
    
    func syncReadProfileInfo() {
        self.db.collection(Users.name).document(self.uid).getDocument(completion: {
            doc, error in
            if doc != nil && error == nil {
                self.name = doc?.get(Users.fields.DISPLAY_NAME) as? String
                self.age = doc?.get(Users.fields.AGE) as? Int
                self.photoURL = doc?.get(Users.fields.PHOTO_URL) as? String
                if self.photoURL != nil {
                    self.initializePhoto()
                }
                self.calcMinimumInfoObtained()
                
                self.relationshipStatus = doc?.get(Users.fields.RELATIONSHIP_STATUS) as? String
                self.occupation = doc?.get(Users.fields.OCCUPATION) as? String
                self.instagramUsername = doc?.get(Users.fields.INSTAGRAM_USERNAME) as? String
            }
        })
    }
    
    func writeNewStringValue(attribute: inout String?, firebaseRep: String, newValue: String?) {
        attribute = newValue
        self.db.collection(Users.name).document(self.uid).updateData([firebaseRep: newValue], completion: {
            error in
            if error == nil {
                self.calcMinimumInfoObtained()
            }
            else {
               // TODO: Return some value here for error? Can't reset inout variable.
            }
        })
    }
    
    func writeNewIntValue(attribute: inout Int?, firebaseRep: String, newValue: Int?) {
        attribute = newValue
        self.db.collection(Users.name).document(self.uid).updateData([firebaseRep: newValue], completion: {
            error in
            if error == nil {
                self.calcMinimumInfoObtained()
            }
            else {
               // TODO: Return some value here for error? Can't reset inout variable.
            }
        })
    }
}


struct PullToRefresh: View {
    
    var coordinateSpaceName: String
    var onRefresh: () -> Void
    
    @State var needRefresh: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            if (geo.frame(in: .named(coordinateSpaceName)).midY > 50) {
                Spacer()
                    .onAppear {
                        let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                        impactMed.impactOccurred()
                        needRefresh = true
                    }
            } else if (geo.frame(in: .named(coordinateSpaceName)).maxY < 10) {
                Spacer()
                    .onAppear {
                        if needRefresh {
                            needRefresh = false
                            onRefresh()
                        }
                    }
            }
            HStack {
                Spacer()
                VStack {
                    if needRefresh {
                        ProgressView()
                    }
                    Text("Pull to refresh").padding(.top)
                }
                Spacer()
            }
        }.padding(.top, -50)
    }
}


struct CloseUsersListView: View {
    var locationManager = UserLocation.shared
    @ObservedObject var closestUserData: CloseUserData
    
    var body: some View {
        GeometryReader{ geometry in
            ScrollView {
                PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                    print("PULL TO REFRESH")
                    self.closestUserData.loading = true
                    locationManager.locationManager.requestLocation()
                }
               
                ForEach(self.closestUserData.closeUsers, id:\.self.uid) { user in
                    VStack {
                        // TODO: Maybe put some more checks here
                        if user.name != nil {
                            UserCard(userCardData: user, geometry: geometry)
                        }
                        if user != self.closestUserData.closeUsers.last {
                            HorizontalLine(color: Color("Cyan"), height: 5)
                        }
                    }
                }
            }.coordinateSpace(name: "pullToRefresh")
        }
    }
}

struct UserCard: View {
    @ObservedObject var userCardData: UserCardData
    @State var collapsed: Bool = true
    @Environment(\.colorScheme) var colorScheme
    var geometry: GeometryProxy
    
    var body: some View {
            VStack {
                
                // Main info that will always be displayed
                HStack {

                    // User's profile photo
                    Image(uiImage: self.userCardData.photo).fitToAspectRatio(.square)
                    // First name and Age
                    VStack {
                        Text(self.userCardData.name!).frame(width: geometry.size.width * 0.55, alignment: .leading).foregroundColor(Color("Cyan")).font(.system(size: 30)).offset(x: 10)
                        if self.userCardData.age != nil {
                            Text(String(self.userCardData.age!)).bold().foregroundColor(Color("Cyan")).font(.system(size: 30)).frame(width: geometry.size.width * 0.55, alignment: .leading).offset(x: 10)
                        }
                    }
                }.frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    alignment: .leading
                  )
                
                // Extra info that will only be displayed on expanding the view
                if !self.collapsed {
                    VStack(alignment: .leading) {
                        if self.userCardData.relationshipStatus != nil && self.userCardData.relationshipStatus != "Don't show" {
                            HStack {
                                Image(systemName: "heart").foregroundColor(.white)
                                Text(self.userCardData.relationshipStatus!).foregroundColor(.white).font(.system(size: 20))
                            }
                        }
                       
                        if self.userCardData.occupation != nil {
                            HStack {
                                Image(systemName: "briefcase").foregroundColor(.white)
                                Text(self.userCardData.occupation!).foregroundColor(.white).font(.system(size: 20))
                            }
                        }
                        
                        if self.userCardData.instagramUsername != nil {
                            Button(action: {
                                let instagramHooks = "instagram://user?username=\(self.userCardData.instagramUsername!)"
                                let instagramUrl = URL(string: instagramHooks)
                                if UIApplication.shared.canOpenURL(instagramUrl!) {
                                  UIApplication.shared.open(instagramUrl!)
                                } else {
                                  // TODO: Do something about this error or user does not have instagram
                                }
                            }) {
                                HStack {
                                    Image("instagram_logo").resizable().frame(width: geometry.size.width * 0.10, height: geometry.size.width * 0.10)
                                    if self.userCardData.instagramUsername != nil {
                                        Text("\(self.userCardData.instagramUsername!)").foregroundColor(Color("Cyan"))
                                    }
                                    else {
                                        Text("Link Instagram").foregroundColor(Color("Cyan"))
                                    }
                                }
                            }
                        }
                    }
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        alignment: .leading
                    ).padding()
                }
            }.contentShape(Rectangle()).onTapGesture {
                self.collapsed.toggle()
            }
    }
}

struct HorizontalLineShape: Shape {

    func path(in rect: CGRect) -> Path {

        let fill = CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height)
        var path = Path()
        path.addRoundedRect(in: fill, cornerSize: CGSize(width: 2, height: 2))

        return path
    }
}

struct HorizontalLine: View {
    private var color: Color? = nil
    private var height: CGFloat = 1.0

    init(color: Color, height: CGFloat = 1.0) {
        self.color = color
        self.height = height
    }

    var body: some View {
        HorizontalLineShape().fill(self.color ?? .black).frame(minWidth: 0, maxWidth: .infinity, minHeight: height, maxHeight: height)
    }
}

/// Common aspect ratios
public enum AspectRatio: CGFloat {
    case square = 1
    case threeToFour = 0.75
    case fourToThree = 1.75
}

/// Fit an image to a certain aspect ratio while maintaining its aspect ratio
public struct FitToAspectRatio: ViewModifier {
    
    private let aspectRatio: CGFloat
    
    public init(_ aspectRatio: CGFloat) {
        self.aspectRatio = aspectRatio
    }
    
    public init(_ aspectRatio: AspectRatio) {
        self.aspectRatio = aspectRatio.rawValue
    }
    
    public func body(content: Content) -> some View {
        ZStack {
            Rectangle()
                .fill(Color(.clear))
                .aspectRatio(aspectRatio, contentMode: .fit)

            content
                .scaledToFill()
                .layoutPriority(-1)
        }
        .clipShape(Circle())
    }
}

// Image extension that composes with the `.resizable()` modifier
public extension Image {
    func fitToAspectRatio(_ aspectRatio: CGFloat) -> some View {
        self.resizable().modifier(FitToAspectRatio(aspectRatio))
    }
    
    func fitToAspectRatio(_ aspectRatio: AspectRatio) -> some View {
        self.resizable().modifier(FitToAspectRatio(aspectRatio))
    }
}


struct ActionButton: View {
    
    var width: CGFloat
    var height: CGFloat
    var label: String
    var color: Color
    var action: () -> Void
    
    public init (width: CGFloat, height: CGFloat, label: String, color: Color, action: @escaping () -> Void) {
        self.width = width
        self.height = height
        self.label = label
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            self.action()
        }) {
            Text(self.label).font(.system(size: 25)).bold().foregroundColor(.black).frame(width: self.width * 0.50, height: self.height * 0.05).padding()
        }.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(self.color))
    }
    
}
