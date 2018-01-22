//
//  ViewController.swift
//  GooglePlacesSearchController
//
//  Created by Dmitry Shmidt on 6/28/15.
//  Copyright (c) 2015 Dmitry Shmidt. All rights reserved.
//

import UIKit
import CoreLocation
import GooglePlacesSearchController

class ViewController: UIViewController {
    
    @IBOutlet weak var streetAddressTextField: UITextField! {
        didSet {
            streetAddressTextField.addTarget(self, action: #selector(streetAddressTextFieldEditingDidBegin), for: .editingDidBegin)
        }
    }
    
    private let GoogleMapsAPIServerKey = "YOUR_KEY"
    
    private lazy var placesSearchController: PlacesSearchController = {
        let controller = PlacesSearchController(
            delegate: self,
            placeType: .address,
            //Optional: coordinate: CLLocationCoordinate2D(latitude: 55.751244, longitude: 37.618423),
            //Optional: radius: 10,
            //Optional: searchBarPlaceholder: "Start typing...",
            googleAPIKey: GoogleMapsAPIServerKey
        )
        
        //Optional: controller.searchBar.isTranslucent = false
        //Optional: controller.searchBar.barStyle = .black
        //Optional: controller.searchBar.tintColor = .white
        //Optional: controller.searchBar.barTintColor = .black
        
        return controller
    }()
    
    @objc func streetAddressTextFieldEditingDidBegin() {
        present(placesSearchController, animated: true, completion: nil)
    }
}

// MARK: - Places autocomplete delegate

extension ViewController: PlacesAutocompleteViewControllerDelegate {
    
    func viewController(didAutocompleteWith place: PlaceDetails) {
        streetAddressTextField.text = place.formattedAddress
        
        //Dismiss Search
        placesSearchController.isActive = false
    }
}
