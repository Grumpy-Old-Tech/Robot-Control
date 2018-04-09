//
//  ViewController.swift
//  SkaterBot
//
//  Created by Neville Kripp on 9/9/17.
//  Copyright © 2017 Neville Kripp. All rights reserved.
//

import UIKit
import CoreBluetooth

class ControlViewController: UIViewController, BluetoothSerialDelegate {

    
    //MARK: IBOutlets
    
    @IBOutlet weak var barButton: UIBarButtonItem!
    @IBOutlet weak var navItem: UINavigationItem!
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var joyStickHolder: UIView!
    @IBOutlet weak var joyStickBackground: UIImageView!
    @IBOutlet weak var joyStickBall: UIImageView!
    
    //MARK: Variables
    
    private var stickActive:Bool = false                            // Indicates stick is moving
    private var lastTouchPosition: CGPoint = CGPoint(x: 0, y: 0)    // Last location saved
    private var maxVector: CGVector = CGVector(dx: 0, dy: 0)        // Indicates the constraint of the joystick location from centre
    
    private var timer: Timer!                                       // Serial send timer
    
    //MARK: View functions
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Initialise the Bluetooth
        serial = BluetoothSerial(delegate: self)
        
        reloadView()
        
        // Setup observer for return from selection view
        NotificationCenter.default.addObserver(self, selector: #selector(ControlViewController.reloadView), name: NSNotification.Name(rawValue: "reloadStartViewController"), object: nil)
        
        timer = Timer.scheduledTimer(timeInterval: 0.10, target: self, selector: #selector(sendInfo), userInfo: nil, repeats: true)
    }
    
    deinit {
        
        // remove reload observer
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        
        super.didReceiveMemoryWarning()

    }
    
    @objc func reloadView() {
        
        // Set the delegate to this view again
        serial.delegate = self
        
        // Change the view header to display the state of bluetooth and device connection
        if serial.isReady {
            
            self.navigationController?.navigationBar.backgroundColor = UIColor.green
            barButton.isEnabled = false
        }
        else if serial.centralManager.state == .poweredOn {
            
            self.navigationController?.navigationBar.backgroundColor = UIColor.yellow
            barButton.isEnabled = true
        }
        else {
            self.navigationController?.navigationBar.backgroundColor = UIColor.red
            barButton.isEnabled = false
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        for touch in touches {
            
            let location = touch.location(in: joyStickBall)
            
            if joyStickBall.bounds.contains(location) {
                
                // Touch has started on joystick ball, save and set active
                stickActive = true
                maxVector = CGVector(dx: 0, dy: 0)
                let location = touch.location(in: joyStickHolder)
                lastTouchPosition = location
            }
            else {
                
                // Not touched in ball so set inactive
                stickActive = false
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if stickActive {
            
            // Stick is active to set to return to centre with animation
            maxVector = CGVector(dx: 0, dy: 0)
            UIView.animate(withDuration: 0.2, animations: {self.joyStickBall.center = self.joyStickBackground.center}, completion: nil)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        for touch in touches {
            
            if stickActive {
                
                // get the location in relation to the joystick holder view
                let location = touch.location(in: joyStickHolder)
                
                // Determine the vector from the last position
                let difference: CGVector = CGVector(dx: location.x - lastTouchPosition.x, dy: location.y - lastTouchPosition.y)
                lastTouchPosition = location
                
                // Determine where the joystick centre is now
                let newCenter:CGPoint = CGPoint(x: joyStickBall.center.x + difference.dx, y: joyStickBall.center.y + difference.dy)
                
                // Determine the vector from the background centre to the joystick centre
                let centerV: CGVector = CGVector(dx: newCenter.x - joyStickBackground.center.x, dy: newCenter.y - joyStickBackground.center.y)
                let angle = atan2(centerV.dy, centerV.dx)
                
                // Determine the ball constrain vector
                let length:CGFloat = joyStickBackground.frame.size.height / 4
                let xDist:CGFloat = sin(angle - 1.57079633) * length
                let yDist:CGFloat = cos(angle - 1.57079633) * length
                maxVector = CGVector(dx: xDist, dy: yDist)

                // If the new joystick ball location is less than the constraint just location the view else put at constraint location
                if abs(centerV.dx) < abs(maxVector.dx)  && abs(centerV.dy) < abs(maxVector.dy) {
                    
                    joyStickBall.center = CGPoint(x: newCenter.x, y: newCenter.y)
                }
                else {
                    
                    joyStickBall.center = CGPoint(x: joyStickBackground.center.x - xDist, y: joyStickBackground.center.y + yDist)
                }
            }
        }
    }
    
    //MARK: Bluetooth Serial functions
    
    @objc func sendInfo() {
        
        // If a device is connected, send the commands if ball has been moved.
        if serial.isReady {
            
            var byteToSend:UInt8 = 0b00000000
            
            if maxVector.dx > 30 {
                
                // Left
                byteToSend |= 0b00000001
            }
            else if maxVector.dx < -30 {
                
                // Right
                byteToSend |= 0b00000010
            }
            
            if maxVector.dy > 30 {
                
                // Back
                byteToSend |= 0b00001000
            }
            else if maxVector.dy < -30 {
                
                // Forward
                byteToSend |= 0b00000100
            }
            
            if byteToSend > 0 {
            
                let msg:String! = String(bytes: [byteToSend], encoding: .ascii)
                serial.sendMessageToDevice(msg)
            }
        }
    }
    
    //MARK: BluetoothSerialDelegate
    
    func serialDidReceiveString(_ message: String) {
        
        textView.text! += message
        
        // Scroll to show last character
        let range = NSMakeRange(NSString(string: textView.text).length - 1, 1)
        textView.scrollRangeToVisible(range)
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {

        reloadView()
        
        // Display alert
        let alert = UIAlertController(title: "Problem", message: "Device disconnected", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func serialDidChangeState() {

        reloadView()
        
        if serial.centralManager.state != .poweredOn {
            
            // Display alert
            let alert = UIAlertController(title: "Problem", message: "Bluetooth turned off", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    //MARK: IBActions
    
    @IBAction func barButtonPressed(_ sender: AnyObject) {
        
        if serial.connectedPeripheral == nil {
            
            performSegue(withIdentifier: "ShowDevices", sender: self)
        }
        else {
            
            serial.disconnect()
            reloadView()
        }
    }
}


