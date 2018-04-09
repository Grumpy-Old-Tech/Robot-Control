//
//  DeviceViewController.swift
//  SkaterBot
//
//  Created by Neville Kripp on 9/9/17.
//  Copyright © 2017 Neville Kripp. All rights reserved.
//

import UIKit
import CoreBluetooth

class DeviceViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, BluetoothSerialDelegate {

    //MARK: Outlets
    
    @IBOutlet weak var reScanButton: UIBarButtonItem!
    @IBOutlet weak var deviceTableView: UITableView!
    @IBOutlet weak var connectIndicator: UIActivityIndicatorView!

    //MARK: Variables
    
    var devices: [(peripheral: CBPeripheral, RSSI: Float)] = []     // The device that have been found (no duplicates and sorted by asc RSSI)
    var selectedDevice: CBPeripheral?                               // The selected device
    
    
    //MARK: View functions
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Rescan button is only available when not scanning
        reScanButton.isEnabled = false
        
        
 //       deviceTableView.tableFooterView = UIView(frame: CGRect.zero)
        
        // Set view to respond to delegate function calls
        serial.delegate = self
        
        // Display alert if Bluetooth is not enabled
        if serial.centralManager.state != .poweredOn {
            
            title = "Devices"
            let alert = UIAlertController(title: "Problem", message: "Bluetooth not turned on", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            
            return
        }
        
        // Start scanning for devices, set a timeout as well
        title = "Scanning"
        serial.startScan()
        Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(DeviceViewController.scanTimeOut), userInfo: nil, repeats: false)
    }
    
    override func didReceiveMemoryWarning() {
        
        super.didReceiveMemoryWarning()
    }
    
    @objc func scanTimeOut() {
        
        // If timeout occurs, enable rescan button
        serial.stopScan()
        reScanButton.isEnabled = true
        title = "Devices"
    }
    
    @objc func connectTimeOut() {
        
        // If already connected, do nothing
        if let _ = serial.connectedPeripheral {
            return
        }
        
        connectIndicator.isHidden = true
        
        // If a device is selected, remove it
        if let _ = selectedDevice{
            serial.disconnect()
            selectedDevice = nil
        }
        
        // Display alert
        let alert = UIAlertController(title: "Problem", message: "Failed to connect", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    
    //MARK: UITableView DataSource functions
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return devices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Display the device name in the cell
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell")!
        let label = cell.viewWithTag(1) as! UILabel!
        label?.text = devices[(indexPath as NSIndexPath).row].peripheral.name
        return cell
    }
    
    
    //MARK: UITableView Delegate functions
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Device selected, so stop scanning and connect, set timeout also
        serial.stopScan()
        selectedDevice = devices[(indexPath as NSIndexPath).row].peripheral
        serial.connectToPeripheral(selectedDevice!)
        
        connectIndicator.isHidden = false
        Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(DeviceViewController.connectTimeOut), userInfo: nil, repeats: false)
    }
    
    
    //MARK: BluetoothSerial Delegate functions
    
    func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {
        
        // Check whether it is a duplicate
        for exisiting in devices {
            
            if exisiting.peripheral.identifier == peripheral.identifier {
                
                return
            }
        }
        
        // Add to the array, next sort & reload
        let theRSSI = RSSI?.floatValue ?? 0.0
        devices.append((peripheral: peripheral, RSSI: theRSSI))
        devices.sort { $0.RSSI < $1.RSSI }
        deviceTableView.reloadData()
    }
    
    func serialDidFailToConnect(_ peripheral: CBPeripheral, error: NSError?) {
        
        connectIndicator.isHidden = true
        reScanButton.isEnabled = true
        
        // Display alert
        let alert = UIAlertController(title: "Problem", message: "Failed to connect", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        
        connectIndicator.isHidden = true
        reScanButton.isEnabled = true
        
        // Display alert
        let alert = UIAlertController(title: "Problem", message: "Failed to connect", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func serialIsReady(_ peripheral: CBPeripheral) {
        
        connectIndicator.isHidden = true
        
        // Return to main view
        NotificationCenter.default.post(name: Notification.Name(rawValue: "reloadStartViewController"), object: self)
        dismiss(animated: true, completion: nil)
    }
    
    func serialDidChangeState() {
        
        connectIndicator.isHidden = true
        
        // Return to main view power bluetooth is off
        if serial.centralManager.state != .poweredOn {
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: "reloadStartViewController"), object: self)
            dismiss(animated: true, completion: nil)
        }
    }
    
    
    //MARK: IBAction functions
    
    @IBAction func cancel(_ sender: AnyObject) {
        
        // Return to main view
        serial.stopScan()
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func tryAgain(_ sender: AnyObject) {
        
        // Restart scan process and set timeout again
        devices = []
        deviceTableView.reloadData()
        reScanButton.isEnabled = false
        title = "Scanning"
        serial.startScan()
        
        connectIndicator.isHidden = false
        Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(DeviceViewController.scanTimeOut), userInfo: nil, repeats: false)
    }
    
}
