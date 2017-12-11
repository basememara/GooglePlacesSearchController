//
//  GooglePlacesAutocomplete.swift
//  GooglePlacesAutocomplete
//
//  Created by Howard Wilson on 10/02/2015.
//  Copyright (c) 2015 Howard Wilson. All rights reserved.
//
//
//  Created by Dmitry Shmidt on 6/28/15.
//  Copyright (c) 2015 Dmitry Shmidt. All rights reserved.

import UIKit
import CoreLocation
import MapKit

public struct Place {
    public let mainAddress: String
    public let secondaryAddress: String
    
    fileprivate var googlePlaceID: String?
    fileprivate var appleSearchCompletion: MKLocalSearchCompletion?
    
    init(mainAddress: String, secondaryAddress: String) {
        self.mainAddress = mainAddress
        self.secondaryAddress = secondaryAddress
    }
    
    /// Google API initializer
    init(prediction: [String: Any]) {
        let structuredFormatting = prediction["structured_formatting"] as? [String: Any]
        
        self.init(
            mainAddress: structuredFormatting?["main_text"] as? String ?? "",
            secondaryAddress: structuredFormatting?["secondary_text"] as? String ?? ""
        )
        
        self.googlePlaceID = prediction["place_id"] as? String ?? ""
    }
    
    /// Apple API initializer
    init(searchCompletion: MKLocalSearchCompletion) {
        self.init(
            mainAddress: searchCompletion.title,
            secondaryAddress: searchCompletion.subtitle
        )
        
        self.appleSearchCompletion = searchCompletion
    }
}

public struct PlaceDetails {
    public let formattedAddress: String
    public var streetNumber: String? = nil
    public var route: String? = nil
    public var postalCode: String? = nil
    public var city: String? = nil
    public var state: String? = nil
    public var country: String? = nil
    public var ISOcountryCode: String? = nil
    
    public var coordinate: CLLocationCoordinate2D? = nil
    
    /// Google API initializer
    init?(json: [String: Any]) {
        guard let result = json["result"] as? [String: Any],
            let formattedAddress = result["formatted_address"] as? String
            else { return nil }
        
        self.formattedAddress = formattedAddress
        
        if let addressComponents = result["address_components"] as? [[String: Any]] {
            enum ComponentType: String {
                case short = "short_name"
                case long = "long_name"
            }
            
            /// Parses the element value with the specified type from the array or components.
            /// Example: `{ "long_name" : "90", "short_name" : "90", "types" : [ "street_number" ] }`
            func get(_ component: String, from array: [[String: Any]], ofType: ComponentType) -> String? {
                return (array.first { ($0["types"] as? [String])?.contains(component) == true })?[ofType.rawValue] as? String
            }
            
            self.streetNumber = get("street_number", from: addressComponents, ofType: .short)
            self.route = get("route", from: addressComponents, ofType: .short)
            self.postalCode = get("postal_code", from: addressComponents, ofType: .long)
            self.city = get("locality", from: addressComponents, ofType: .long)
            self.state = get("administrative_area_level_1", from: addressComponents, ofType: .short)
            self.country = get("country", from: addressComponents, ofType: .long)
            self.ISOcountryCode = get("country", from: addressComponents, ofType: .short)
        }
        
        if let geometry = result["geometry"] as? [String: Any],
            let location = geometry["location"] as? [String: Any],
            let latitude = location["lat"] as? CLLocationDegrees,
            let longitude = location["lng"] as? CLLocationDegrees {
            self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    /// Apple API initializer
    init?(from placemark: MKPlacemark) {
        guard let title = placemark.title else { return nil }
        
        self.formattedAddress = title
        
        self.streetNumber = placemark.subThoroughfare ?? ""
        self.route = placemark.thoroughfare ?? ""
        self.postalCode = placemark.postalCode ?? ""
        self.city = placemark.subAdministrativeArea ?? ""
        self.state = placemark.administrativeArea ?? ""
        self.country = placemark.country ?? ""
        self.ISOcountryCode = placemark.isoCountryCode ?? ""
        
        self.coordinate = placemark.coordinate
    }
}

open class PlacesSearchController: UISearchController, UISearchBarDelegate {
    
    convenience public init(delegate: PlacesAutocompleteViewControllerDelegate, placeType: PlacesAutocompleteContainer.PlaceType = .address, coordinate: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid, radius: CLLocationDistance = 0, searchBarPlaceholder: String = "Enter Address", googleAPIKey: String) {
        assert(!googleAPIKey.isEmpty, "Provide your Google API key")
        
        let tableViewController = PlacesAutocompleteContainer(
            delegate: delegate,
            placeType: placeType,
            coordinate: coordinate,
            radius: radius,
            googleAPIKey: googleAPIKey
        )
        
        self.init(searchResultsController: tableViewController)
        
        self.searchResultsUpdater = tableViewController
        self.hidesNavigationBarDuringPresentation = false
        self.definesPresentationContext = true
        self.searchBar.placeholder = searchBarPlaceholder
    }
}

public protocol PlacesAutocompleteViewControllerDelegate: class {
    func viewController(didAutocompleteWith place: PlaceDetails)
}

open class PlacesAutocompleteContainer: UITableViewController {
    private weak var delegate: PlacesAutocompleteViewControllerDelegate?
    
    private var placeType: PlaceType = .address
    private var coordinate: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    private var radius: Double = 0.0
    private let cellIdentifier = "Cell"
    
    private var places = [Place]() {
        didSet { tableView.reloadData() }
    }
    
    private var googleAPIKey: String = ""
    
    // Apple Maps fallback
    private lazy var appleSearchCompleter: MKLocalSearchCompleter = {
        let searchCompleter = MKLocalSearchCompleter()
        searchCompleter.delegate = self
        searchCompleter.filterType = placeType == .all ? .locationsAndQueries : .locationsOnly
        
        // Set region scoped search if applicable
        if CLLocationCoordinate2DIsValid(self.coordinate) {
            let radius = self.radius > 0 ? self.radius : 50_000 //Default to 50km
            let region = MKCoordinateRegionMakeWithDistance(self.coordinate, radius, radius)
            searchCompleter.region = MKCoordinateRegion(center: self.coordinate, span: region.span)
        }
        
        return searchCompleter
    }()
    
    private var appleSearchCompletion = [MKLocalSearchCompletion]() {
        didSet { places = appleSearchCompletion.map { Place(searchCompletion: $0) } }
    }
    
    convenience init(delegate: PlacesAutocompleteViewControllerDelegate, placeType: PlaceType = .all, coordinate: CLLocationCoordinate2D, radius: Double, googleAPIKey: String) {
        self.init()
        self.delegate = delegate
        self.placeType = placeType
        self.coordinate = coordinate
        self.radius = radius
        self.googleAPIKey = googleAPIKey
    }
}

extension PlacesAutocompleteContainer {
    
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return places.count
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        
        let place = places[indexPath.row]
        
        cell.textLabel?.text = place.mainAddress
        cell.detailTextLabel?.text = place.secondaryAddress
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let place = places[indexPath.row]
        
        // Use Google or fallback on Apple
        guard let googlePlaceID = place.googlePlaceID, !googlePlaceID.isEmpty else {
            debugPrint("GooglePlaces failed, fallback on Apple MapKit")
            
            guard let searchCompletion = place.appleSearchCompletion else { return }
            let searchRequest = MKLocalSearchRequest(completion: searchCompletion)
            
            return MKLocalSearch(request: searchRequest).start { response, error in
                guard let placemark = response?.mapItems.first?.placemark,
                    let placeDetails = PlaceDetails(from: placemark)
                    else { return }
                
                DispatchQueue.main.async {
                    self.delegate?.viewController(didAutocompleteWith: placeDetails)
                }
            }
        }
        
        GoogleAPIHelpers.getPlaceDetails(id: googlePlaceID, googleAPIKey: googleAPIKey) { [unowned self] in
            guard let value = $0 else { return }
            
            DispatchQueue.main.async {
                self.delegate?.viewController(didAutocompleteWith: value)
            }
        }
    }
}

extension PlacesAutocompleteContainer: UISearchBarDelegate, UISearchResultsUpdating {
    
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard !searchText.isEmpty else { places = []; return }
        performAddressSearch(for: searchText)
    }
    
    public func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text, !searchText.isEmpty else { places = []; return }
        performAddressSearch(for: searchText)
    }
    
    private func performAddressSearch(for text: String) {
        let parameters = getParameters(for: text)
        
        GoogleAPIHelpers.getPlaces(with: parameters) {
            guard let places = $0 else {
                debugPrint("GooglePlaces failed, fallback on Apple MapKit")
                self.appleSearchCompleter.queryFragment = parameters["input"] ?? ""
                return
            }
            
            self.places = places
        }
    }
    
    private func getParameters(for text: String) -> [String: String] {
        var params = [
            "input": text,
            "types": placeType.rawValue,
            "key": googleAPIKey
        ]
        
        if CLLocationCoordinate2DIsValid(coordinate) {
            params["location"] = "\(coordinate.latitude),\(coordinate.longitude)"
            
            if radius > 0 {
                params["radius"] = "\(radius)"
            }
        }
        
        return params
    }
}

// MARK: - Apple API delegate for fallback case
extension PlacesAutocompleteContainer: MKLocalSearchCompleterDelegate {
    
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        appleSearchCompletion = completer.results
    }
    
    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        debugPrint(error.localizedDescription)
    }
}

extension PlacesAutocompleteContainer {
    
    public enum PlaceType: String {
        case all = ""
        case geocode
        case address
        case establishment
        case regions = "(regions)"
        case cities = "(cities)"
    }
}

private struct GoogleAPIHelpers {
    
    private init() { }
    
    private static func request(_ urlString: String, params: [String: String], completion: @escaping ([String: Any]?) -> Void) {
        var components = URLComponents(string: urlString)
        components?.queryItems = params.map { URLQueryItem(name: $0, value: $1) }
        
        guard let url = components?.url else { return }
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error {
                debugPrint("GooglePlaces Error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data, let response = response as? HTTPURLResponse else {
                debugPrint("GooglePlaces Error: No response from API")
                completion(nil)
                return
            }
            
            guard response.statusCode == 200 else {
                debugPrint("GooglePlaces Error: Invalid status code \(response.statusCode) from API")
                completion(nil)
                return
            }
            
            let object: [String: Any]?
            do {
                object = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]
            } catch {
                debugPrint("GooglePlaces Error")
                completion(nil)
                return
            }
            
            guard object?["status"] as? String == "OK" else {
                debugPrint("GooglePlaces API Error: \(object?["status"] ?? "")")
                completion(nil)
                return
            }
            
            guard let json = object else {
                debugPrint("GooglePlaces Parse Error")
                completion(nil)
                return
            }
            
            completion(json)
        })
        
        task.resume()
    }
    
    static func getPlaces(with parameters: [String: String], completion: @escaping ([Place]?) -> Void) {
        request(
            "https://maps.googleapis.com/maps/api/place/autocomplete/json",
            params: parameters,
            completion: { result in
                DispatchQueue.main.async {
                    let predictions = result?["predictions"] as? [[String: Any]]
                    completion(predictions?.map { Place(prediction: $0) })
                }
        }
        )
    }
    
    static func getPlaceDetails(id: String, googleAPIKey: String, completion: @escaping (PlaceDetails?) -> Void) {
        request(
            "https://maps.googleapis.com/maps/api/place/details/json",
            params: ["placeid": id, "key": googleAPIKey],
            completion: { result in
                DispatchQueue.main.async {
                    completion(PlaceDetails(json: result ?? [:]))
                }
        }
        )
    }
}
