//
//  PickTimeViewController.swift
//  PickTimeViewController
//
//  Created by Daniel Torres on 27/8/21.
//

import UIKit
import Haptica

class PickTimeViewController: UIViewController {

    @IBOutlet weak var timePicker: UIPickerView!
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var doneButton: UIButton!
    
    var times = ["5", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55", "60", "65", "70", "75", "80", "85", "90", "95", "100", "105", "110", "115", "120"]
    var rotationAngle: CGFloat! = -90 * (.pi/180)
    var selectedTime: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        container.layer.cornerRadius = 20
        timePicker.dataSource = self
        timePicker.delegate = self
        self.container.addSubview(timePicker)
        timePicker.transform = CGAffineTransform(rotationAngle: rotationAngle)
        timePicker.frame = CGRect(x: -150, y: 62, width: container.bounds.width + 300, height: 80)
        print(timePicker.subviews.count)
        doneButton.addHaptic(.impact(.heavy), forControlEvents: .touchDown)
        
        
        if let incomingSelectedTime = selectedTime {
            print("Time is \(incomingSelectedTime)")
            timePicker.selectRow(times.firstIndex(of: String(incomingSelectedTime))!, inComponent: 0, animated: true)
        } else {
            timePicker.selectRow(1, inComponent: 0, animated: true)
            selectedTime = 10
        }

        // TODO: Cambiar fondo de la row seleccionada en el pickerview
    }
    
    
}

extension PickTimeViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return times.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        
        let modeView = UIView()
        
        modeView.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        let modeLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        
        modeLabel.textColor = .systemBlue
        modeLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 20)
        
        modeLabel.text = times[row]
        
        modeLabel.textAlignment = .center
        modeView.addSubview(modeLabel)
        
        modeView.transform = CGAffineTransform(rotationAngle: 90 * (.pi/180))
    
        
        return modeView
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
      return 70
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
       selectedTime = Int(times[row])
    }
    
}
