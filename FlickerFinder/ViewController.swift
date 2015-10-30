//
//  ViewController.swift
//  FlickerFinder
//
//  Created by Ahmed Onawale on 10/29/15.
//  Copyright © 2015 Ahmed Onawale. All rights reserved.
//

/* 1 - Define constants */
let BASE_URL = "https://api.flickr.com/services/rest/"
let METHOD_NAME = "flickr.photos.search"
let API_KEY = "f947e0c7616d988826e195d158caf794"
let EXTRAS = "url_m"
let DATA_FORMAT = "json"
let NO_JSON_CALLBACK = "1"
let SAFE_SEARCH = "1"

let BOUNDING_BOX_HALF_WIDTH = 1.0
let BOUNDING_BOX_HALF_HEIGHT = 1.0
let LAT_MIN = -90.0
let LAT_MAX = 90.0
let LON_MIN = -180.0
let LON_MAX = 180.0

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var defaultLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    
    @IBAction func searchPhotosByPhrase(sender: UIButton) {
        dismissAnyVisibleKeyboards()
        /* 2 - API method arguments */
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            let methodArguments: [String: String!] = [
                "method": METHOD_NAME,
                "api_key": API_KEY,
                "text": self.phraseTextField.text,
                "safe_search": SAFE_SEARCH,
                "extras": EXTRAS,
                "format": DATA_FORMAT,
                "nojsoncallback": NO_JSON_CALLBACK
            ]
            getImageFromFlickrBySearch(methodArguments)
        } else {
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchPhotosByLatLOng(sender: UIButton) {
        dismissAnyVisibleKeyboards()
        if !latitudeTextField.text!.isEmpty && !longitudeTextField.text!.isEmpty {
            if validLatitude() && validLongitude() {
                photoTitleLabel.text = "Searching..."
                let methodArguments = [
                    "method": METHOD_NAME,
                    "api_key": API_KEY,
                    "bbox": createBoundingBoxString(),
                    "safe_search": SAFE_SEARCH,
                    "extras": EXTRAS,
                    "format": DATA_FORMAT,
                    "nojsoncallback": NO_JSON_CALLBACK
                ]
                getImageFromFlickrBySearch(methodArguments)
            } else {
                if !validLatitude() && !validLongitude() {
                    photoTitleLabel.text = "Lat/Lon Invalid.\nLat should be [-90, 90].\nLon should be [-180, 180]."
                } else if !validLatitude() {
                    photoTitleLabel.text = "Lat Invalid.\nLat should be [-90, 90]."
                } else {
                    photoTitleLabel.text = "Lon Invalid.\nLon should be [-180, 180]."
                }
            }
        } else {
            if latitudeTextField.text!.isEmpty && longitudeTextField.text!.isEmpty {
                photoTitleLabel.text = "Lat/Lon Empty."
            } else if latitudeTextField.text!.isEmpty {
                photoTitleLabel.text = "Lat Empty."
            } else {
                photoTitleLabel.text = "Lon Empty."
            }
        }
    }
    
    private func getImageFromFlickrBySearch(methodArguments: [String: AnyObject]) {
        let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        let task = session.dataTaskWithRequest(request) { data, response, error in
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                print("There was an error with your request: \(error)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                if let response = response as? NSHTTPURLResponse {
                    print("Your request returned an invalid response! Status code: \(response.statusCode)!")
                } else if let response = response {
                    print("Your request returned an invalid response! Response: \(response)!")
                } else {
                    print("Your request returned an invalid response!")
                }
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                print("No data was returned by the request!")
                return
            }
            
            /* Parse the data! */
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                parsedResult = nil
                print("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error? */
            guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                print("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Is "photos" key in our result? */
            guard let photosDictionary = parsedResult["photos"] as? NSDictionary else {
                print("Cannot find keys 'photos' in \(parsedResult)")
                return
            }
            
            /* GUARD: Is "pages" key in the photosDictionary? */
            guard let totalPages = photosDictionary["pages"] as? Int else {
                print("Cannot find key 'pages' in \(photosDictionary)")
                return
            }
            
            /* Flickr API will only return up the 4000 images (100 per page * 40 page max) */
            /* Pick a random page! */
            let pageLimit = min(totalPages, 40)
            let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            self.getImageFromFlickrBySearchWithPage(methodArguments, pageNumber: randomPage)
        }
        task.resume()
    }
    
    func getImageFromFlickrBySearchWithPage(methodArguments: [String : AnyObject], pageNumber: Int) {
        
        /* Add the page to the method's arguments */
        var withPageDictionary = methodArguments
        withPageDictionary["page"] = pageNumber
        
        let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(withPageDictionary)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                print("There was an error with your request: \(error)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                if let response = response as? NSHTTPURLResponse {
                    print("Your request returned an invalid response! Status code: \(response.statusCode)!")
                } else if let response = response {
                    print("Your request returned an invalid response! Response: \(response)!")
                } else {
                    print("Your request returned an invalid response!")
                }
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                print("No data was returned by the request!")
                return
            }
            
            /* Parse the data! */
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                parsedResult = nil
                print("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                print("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Is the "photos" key in our result? */
            guard let photosDictionary = parsedResult["photos"] as? NSDictionary else {
                print("Cannot find key 'photos' in \(parsedResult)")
                return
            }
            
            /* GUARD: Is the "total" key in photosDictionary? */
            guard let totalPhotosVal = (photosDictionary["total"] as? NSString)?.integerValue else {
                print("Cannot find key 'total' in \(photosDictionary)")
                return
            }
            
            if totalPhotosVal > 0 {
                
                /* GUARD: Is the "photo" key in photosDictionary? */
                guard let photosArray = photosDictionary["photo"] as? [[String: AnyObject]] else {
                    print("Cannot find key 'photo' in \(photosDictionary)")
                    return
                }
                
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photosArray.count)))
                let photoDictionary = photosArray[randomPhotoIndex] as [String: AnyObject]
                let photoTitle = photoDictionary["title"] as? String /* non-fatal */
                
                /* GUARD: Does our photo have a key for 'url_m'? */
                guard let imageUrlString = photoDictionary["url_m"] as? String else {
                    print("Cannot find key 'url_m' in \(photoDictionary)")
                    return
                }
                
                let imageURL = NSURL(string: imageUrlString)
                if let imageData = NSData(contentsOfURL: imageURL!) {
                    dispatch_async(dispatch_get_main_queue(), {
                        
                        self.defaultLabel.alpha = 0.0
                        self.photoImageView.image = UIImage(data: imageData)
                        
                        if methodArguments["bbox"] != nil {
                            if let photoTitle = photoTitle {
                                self.photoTitleLabel.text = "\(self.getLatLonString()) \(photoTitle)"
                            } else {
                                self.photoTitleLabel.text = "\(self.getLatLonString()) (Untitled)"
                            }
                        } else {
                            self.photoTitleLabel.text = photoTitle ?? "(Untitled)"
                        }
                    })
                } else {
                    print("Image does not exist at \(imageURL)")
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    self.photoTitleLabel.text = "No Photos Found. Search Again."
                    self.defaultLabel.alpha = 1.0
                    self.photoImageView.image = nil
                })
            }
        }
        
        task.resume()
    }
    
    /* Helper function: Given a dictionary of parameters, convert to a string for a url */
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    func createBoundingBoxString() -> String {
        let latitude = (latitudeTextField.text! as NSString).doubleValue
        let longitude = (longitudeTextField.text! as NSString).doubleValue
        
        /* Fix added to ensure box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude - BOUNDING_BOX_HALF_WIDTH, LON_MIN)
        let bottom_left_lat = max(latitude - BOUNDING_BOX_HALF_HEIGHT, LAT_MIN)
        let top_right_lon = min(longitude + BOUNDING_BOX_HALF_HEIGHT, LON_MAX)
        let top_right_lat = min(latitude + BOUNDING_BOX_HALF_HEIGHT, LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
    
    func getLatLonString() -> String {
        let latitude = (self.latitudeTextField.text! as NSString).doubleValue
        let longitude = (self.longitudeTextField.text! as NSString).doubleValue
        
        return "(\(latitude), \(longitude))"
    }
    
    /* Check to make sure the latitude falls within [-90, 90] */
    func validLatitude() -> Bool {
        if let latitude : Double? = latitudeTextField.text!.toDouble() {
            if latitude < LAT_MIN || latitude > LAT_MAX {
                return false
            }
        } else {
            return false
        }
        return true
    }
    
    /* Check to make sure the longitude falls within [-180, 180] */
    func validLongitude() -> Bool {
        if let longitude : Double? = longitudeTextField.text!.toDouble() {
            if longitude < LON_MIN || longitude > LON_MAX {
                return false
            }
        } else {
            return false
        }
        return true
    }
    
    func keyboardWillShow(notification: NSNotification) {
        if photoImageView.image != nil {
            defaultLabel.alpha = 0.0
        }
        if self.view.frame.origin.y == 0.0 {
            view.frame.origin.y -= keyboardHeightFromDictionary(notification.userInfo) ?? 0
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if photoImageView.image != nil {
            defaultLabel.alpha = 1.0
        }
        if self.view.frame.origin.y != 0.0 {
            view.frame.origin.y += keyboardHeightFromDictionary(notification.userInfo) ?? 0
        }
    }
    
    private func keyboardHeightFromDictionary(dictionary: [NSObject: AnyObject]?) -> CGFloat? {
        guard let keyboardSize = dictionary?[UIKeyboardFrameEndUserInfoKey] as? NSValue else {
            return nil
        }
        return keyboardSize.CGRectValue().height
    }
    
    private func subscribeToKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
    }
    
    private func unSubscribeFromKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first where touch.view == view else {
            return
        }
        view.endEditing(true)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        subscribeToKeyboardNotifications()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unSubscribeFromKeyboardNotifications()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension ViewController {
    func dismissAnyVisibleKeyboards() {
        if phraseTextField.isFirstResponder() || latitudeTextField.isFirstResponder() || longitudeTextField.isFirstResponder() {
            view.endEditing(true)
        }
    }
}

extension String {
    func toDouble() -> Double? {
        return NSNumberFormatter().numberFromString(self)?.doubleValue
    }
}

