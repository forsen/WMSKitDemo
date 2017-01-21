//
//  ViewController.swift
//  WMSKitDemo
//
//  Created by Erik Haider Forsen on 21/01/2017.
//  Copyright © 2017 Erik Haider Forsen. All rights reserved.
//

import UIKit
import MapKit
import WMSKit

struct WebMapServiceConstants {
    static let baseUrl = "https://openwms.statkart.no/skwms1/wms.kartdata2"
    static let version = "1.3.0"
    static let epsg = "4326"
    static let format = "image/png"
    static let tileSize = "256"
    static let transparent = true
}

class ViewController: UIViewController {

    var layersTable: UITableView!

    var mapView: MKMapView!

    var overlay: WMSTileOverlay

    var strXMLData = ""
    var currentElement = ""
    var passData = false
    var passName = false
    var layer = false
    var layers:[String] = []
    var activeLayers: [String: MKOverlay] = [:]

    required init?(coder aDecoder: NSCoder) {
        self.overlay = WMSTileOverlay(urlArg: "", useMercator: true, wmsVersion: WebMapServiceConstants.version)

        super.init(coder: aDecoder)
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up MapView
        mapView = MKMapView()
        mapView.delegate = self
        let mapWidth = view.frame.size.width
        let mapHeight = view.frame.size.height / 2
        mapView.frame = CGRect.init(x: 0, y: 0, width: mapWidth, height: mapHeight)
        view.addSubview(mapView)
        // done setting up MapView

        // Set up TableView for layers
        layersTable = UITableView()
        layersTable.allowsMultipleSelection = true
        layersTable.delegate = self
        let tableWidth = view.frame.size.width
        let tableHeight = view.frame.size.height/2
        layersTable.frame = CGRect.init(x:0, y:tableHeight, width: tableWidth, height: tableHeight)
        layersTable.dataSource = self
        view.addSubview(layersTable)
        // Done setting up TableView

        getLayers()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

extension ViewController: UITableViewDataSource {
    func populateTable() {
        DispatchQueue.main.async {
            self.layersTable.reloadData()
        }
    }

    func getLayers() {
        let urlString = WebMapServiceConstants.baseUrl + "?request=GetCapabilities&Service=WMS"

        let url = URL(string: urlString)
        URLSession.shared.dataTask(with:url!) { (data, response, error) in
            if error != nil {
                print(error as Any)
            } else {

                let parser = XMLParser(data: data!)
                parser.delegate = self
                let success = parser.parse()

                if success {
                    self.populateTable()
                } else {
                    print("parse failure!")
                }
            }
            }.resume()
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKTileOverlayRenderer(overlay: overlay)
        //renderer.alpha = (overlay as! WMSKTileOverlay).alpha
        return renderer
    }

    func removeWMSLayer(layerIndex: Int) {
        mapView.remove(activeLayers[layers[layerIndex]]!)
    }
    func addWMSLayer(layerIndex: Int) {
        var referenceSystem = ""
        if WebMapServiceConstants.version == "1.1.1" {
            referenceSystem = "SRS"
        } else {
            referenceSystem = "CRS"
        }

        let urlLayers = "layers=\(layers[layerIndex])&"
        let urlVersion = "version=\(WebMapServiceConstants.version)&"
        let urlReferenceSystem = "\(referenceSystem)=EPSG:\(WebMapServiceConstants.epsg)&"
        let urlWidthAndHeight = "width=\(WebMapServiceConstants.tileSize)&height=\(WebMapServiceConstants.tileSize)&"
        let urlFormat = "format=\(WebMapServiceConstants.format)&"
        let urlTransparent = "transparent=\(WebMapServiceConstants.transparent)&"

        let urlString = WebMapServiceConstants.baseUrl + "?styles=&service=WMS&request=GetMap&" + urlLayers + urlVersion + urlReferenceSystem + urlWidthAndHeight + urlFormat + urlTransparent
        var useMercator = false
        if(WebMapServiceConstants.epsg == "900913"){
            useMercator = true
        }

        let overlay = WMSTileOverlay(urlArg: urlString, useMercator: useMercator, wmsVersion: WebMapServiceConstants.version)

        //overlay.alpha = 0.7
        overlay.canReplaceMapContent = false

        activeLayers[layers[layerIndex]] = overlay

        self.mapView.add(overlay)
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return layers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableCell = UITableViewCell()
        tableCell.textLabel?.text = layers[indexPath.row]
        tableCell.accessoryType = tableCell.isSelected ? .checkmark : .none
        tableCell.selectionStyle = .none
        return tableCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        layersTable.cellForRow(at: indexPath)?.accessoryType = .checkmark
        addWMSLayer(layerIndex: indexPath.row)
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        layersTable.cellForRow(at: indexPath)?.accessoryType = .none
        removeWMSLayer(layerIndex: indexPath.row)
    }
}

extension ViewController: XMLParserDelegate {
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        currentElement=elementName;
        if(elementName.lowercased()=="layer" || layer ) {
            layer=true
            if(elementName.lowercased()=="name") {
                passName=true;
                layer=false
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        currentElement="";
        if(elementName.lowercased()=="layer") {
            layer=false
        }
        passName=false;
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(passName){
            print(string)
            layers.append(string)
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("failure error: ", parseError)
    }
}
