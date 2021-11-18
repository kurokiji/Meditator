//
//  ViewController.swift
//  Meditator
//
//  Created by Daniel Torres on 26/8/21.
//

import UIKit
import HealthKit
import Haptica
import AVFoundation
import UserNotifications

class ViewController: UIViewController {
    
    // MARK: - Variables
    // MARK: Outlets
    @IBOutlet weak var circularProgress: CircularProgressView!
    @IBOutlet private weak var restTimeLabel: UILabel!
    @IBOutlet weak var startSessionButton: UIButton!
    @IBOutlet weak var statusImage: UIImageView!
    @IBOutlet weak var pickTimeButton: UIButton!
    @IBOutlet weak var mindfulSessionsTableView: UITableView!
    
    // MARK: Variables del temporizador de la sesión
    var timer: Timer?
    var timeLeft: Int?
    var isOnMindfulSession: Bool?
    
    // MARK: Variables del temporizador de la imagen de estado
    var savingSession: Bool?
    var showImageTimer: Timer?
    var timeToShow = 3
    
    // MARK: Variables de HelthKit
    let healthStore = HKHealthStore()
    let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)
    var sessionStartDate: Date?
    var sessionEndDate: Date?
    var sessions: [HKSample]?
    var sessionsQueryDays: Double = 30
    
    // MARK: Variables de audio y haptic
    var audioPlayer: AVAudioPlayer?
    
    let center = UNUserNotificationCenter.current()
    
    // MARK: - App Control Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if error != nil{
                //TODO: mostrar pop up
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(pauseWhenBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        self.activateHealthKit()
        retrieveMindFulMinutes()
        registerTableViewCells()
        mindfulSessionsTableView.dataSource = self
        mindfulSessionsTableView.delegate = self
        isOnMindfulSession = false
        savingSession = false
        updateLabels()
        hapticButtonConfig()
    }
    
    @objc func pauseWhenBackground(){
        self.timer?.invalidate()
        let shared = UserDefaults.standard
        shared.set(Date(), forKey: "savedTime")
    }
    
    @objc func willEnterForeground(){
        if let savedDated = UserDefaults.standard.object(forKey: "savedTime") as? Date {
            let seconds = getTimeDifference(startDate: savedDated)
            refreshTimer(seconds: seconds)
        }
    }
    
    func getTimeDifference(startDate: Date) -> Int{
        let time = Calendar.current.dateComponents([.second], from: startDate, to: Date())
        return time.second!
    }
    
    func refreshTimer(seconds: Int){
        if MindfulSession.shared.timeLeft != nil {
            MindfulSession.shared.timeLeft! -= seconds
            if MindfulSession.shared.timeLeft! > 0 {
                timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(onTimerFires), userInfo: nil, repeats: true)
            } else {
                sessionCompleted(willPlaySound: false)
            }
        }
    }
    
    // MARK: - Session controller
    @IBAction func startStopSessionAction(_ sender: Any) {
        if !isOnMindfulSession!{
            if let time = MindfulSession.shared.sessionTime{
                MindfulSession.shared.timeLeft = time
                timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(onTimerFires), userInfo: nil, repeats: true)
                isOnMindfulSession = true
                updateLabels()
                sessionStartDate = Date.now
                sendNotification(timeToSend: Double(time))
            }
        } else {
            timer?.invalidate()
            sessionCompleted(willPlaySound: true)
        }
        
    }
    
    func sessionCompleted(willPlaySound: Bool){
        isOnMindfulSession = false
        savingSession = true
        MindfulSession.shared.sessionTime = nil
        updateLabels()
        if willPlaySound {
            playSound()
        }
        Haptic.play("O-O-o-o-o-.-.-.", delay: 0.1)
        showImageTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(showSessionCompletedImage), userInfo: nil, repeats: true)
        sessionEndDate = Date.now
        saveMindfullAnalysis(startTime: sessionStartDate!, endTime: sessionEndDate!)
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PickTime" {
            let controller = segue.destination as! PickTimeViewController
            if let selectedTime = MindfulSession.shared.sessionTime{
                controller.selectedTime = selectedTime / 60
            }
        }
    }
    
    // MARK: - Temporizador de sesión
    @IBAction func setTimer(segue: UIStoryboardSegue!){
        // funcion para volver del picker
        let controller = segue.source as! PickTimeViewController
        if let selectedTime = controller.selectedTime {
            MindfulSession.shared.sessionTime = selectedTime * 60
            MindfulSession.shared.timeLeft = selectedTime * 60
            restTimeLabel.text = secondsToTime(time: selectedTime * 60)
        }
        updateLabels()
    }
    
    @objc func onTimerFires(){
        let fromValueProgress: Float =  1.0 - (Float(MindfulSession.shared.timeLeft!) / Float(MindfulSession.shared.sessionTime!))
        
        MindfulSession.shared.timeLeft! -= 1
        
        restTimeLabel.text = secondsToTime(time: MindfulSession.shared.timeLeft!)
        
        let toValueProgress:Float =  1.0 - (Float(MindfulSession.shared.timeLeft!) / Float(MindfulSession.shared.sessionTime!))
        
        circularProgress.setProgressWithAnimation(duration: 1.0, fromValue: fromValueProgress, tovalue: toValueProgress)
        if MindfulSession.shared.timeLeft! <= 0{
            timer?.invalidate()
            timer = nil
            sessionCompleted(willPlaySound: true)
        }
    }
    
    @objc func showSessionCompletedImage(){
        timeToShow -= 1
        if timeToShow <= 0{
            showImageTimer?.invalidate()
            timer = nil
            savingSession = false
            updateLabels()
        }
    }
    
    func secondsToTime (time : Int) -> String {
        let minutes = time / 60
        let seconds = (time % 3600) % 60
      return String(format: "%02i:%02i", minutes, seconds)
    }
    
    func updateLabels() {
        mindfulSessionsTableView.reloadData()
        if isOnMindfulSession! {
            // PickTime
            pickTimeButton.isEnabled = false
            // Start&Stop
            startSessionButton.setTitle("Stop Session", for: .normal)
            let config = UIImage.SymbolConfiguration(scale: .medium)
            startSessionButton.setImage(UIImage(systemName: "stop.circle", withConfiguration: config), for: .normal)
            startSessionButton.tintColor = UIColor.systemRed
            // Timer
            restTimeLabel.textColor = .systemBlue
            // Circular Progress
            circularProgress.trackClr = UIColor.systemGray5
            circularProgress.progressClr = UIColor.systemBlue
            
        } else {
            if savingSession! {
                statusImage.image = UIImage(systemName: "checkmark.circle")
                statusImage.isHidden = false
                restTimeLabel.isHidden = true
                startSessionButton.isEnabled = false
            } else {
                if MindfulSession.shared.sessionTime == nil {
                    startSessionButton.isEnabled = false
                    statusImage.isHidden = false
                    statusImage.image = UIImage(systemName: "timer")
                    
                } else {
                    startSessionButton.isEnabled = true
                    statusImage.isHidden = true
                    restTimeLabel.isHidden = false
                }
            }
            // PickTime
            pickTimeButton.isEnabled = true
            // Start&Stop
            startSessionButton.setTitle("Start Session", for: .normal)
            let config = UIImage.SymbolConfiguration(scale: .medium)
            startSessionButton.setImage(UIImage(systemName: "play.circle", withConfiguration: config), for: .normal)
            startSessionButton.tintColor = UIColor.systemBlue
            // Timer
            restTimeLabel.textColor = .black
            // Circular progress
            circularProgress.trackClr = UIColor.systemGray5
            circularProgress.progressClr = UIColor.clear
        }
    }
    
    // MARK: - HealthKit Mehods
    func activateHealthKit() {
        // Define what HealthKit data we want to ask to read
        let typestoRead = Set([
            HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.mindfulSession)!
            ])

        // Define what HealthKit data we want to ask to write
        let typestoShare = Set([
            HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.mindfulSession)!
            ])

        // Prompt the User for HealthKit Authorization
        self.healthStore.requestAuthorization(toShare: typestoShare, read: typestoRead) { (success, error) -> Void in
            if !success{
                print("HealthKit Auth error\(error)")
            }
        }
    }
    
    func saveMindfullAnalysis(startTime: Date, endTime: Date) {
        // Create a mindful session with the given start and end time
        let mindfullSample = HKCategorySample(type:mindfulType!, value: 0, start: startTime, end: endTime)

        // Save it to the health store
        healthStore.save(mindfullSample, withCompletion: { (success, error) -> Void in
            if error != nil {return}
            self.retrieveMindFulMinutes()
            print("New data was saved in HealthKit: \(success)")
        })
    }
    
    func retrieveMindFulMinutes() {

        // Use a sortDescriptor to get the recent data first (optional)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        // Get all samples from the last 24 hours
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-1.0 * 60.0 * 60.0 * 24.0 * sessionsQueryDays)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        // Create the HealthKit Query
        let query = HKSampleQuery(
            sampleType: mindfulType!,
            predicate: predicate,
            limit: 8,
            sortDescriptors: [sortDescriptor],
            resultsHandler: updateMeditationTime
        )
        // Execute our query
        healthStore.execute(query)
    }
    
    func updateMeditationTime(query: HKSampleQuery, results: [HKSample]?, error: Error?) {
        if error != nil {return}
        sessions = results
    }
    
    // MARK: - Helper methods
    func playSound(){
        let pathToSound = Bundle.main.path(forResource: "long-chime-sound", ofType: "mp3")
        let url = URL(fileURLWithPath: pathToSound!)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound")
        }
    }
    
    func hapticButtonConfig(){
        startSessionButton.addHaptic(.impact(.heavy), forControlEvents: .touchDown)
        pickTimeButton.addHaptic(.impact(.medium), forControlEvents: .touchDown)
    }
    
    func sendNotification(timeToSend: Double){
        let content = UNMutableNotificationContent()
        content.title = "Session Completed"
        content.body = "Open Meditator to sava your session."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("long-chime-sound.mp3"))
        
        let notificationDate = Date().addingTimeInterval(timeToSend)
        let dateComponents = Calendar.current.dateComponents([.second], from: notificationDate)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)
        
        center.add(request) { (error) in
            if error != nil {
                print(error.debugDescription)
            }
        }
        
    }
    
    // MARK: - TableView Methods
    func registerTableViewCells(){
        let cell = UINib(nibName: "SessionEntryTableViewCell", bundle: nil)
        self.mindfulSessionsTableView.register(cell, forCellReuseIdentifier: "SessionCell")
    }
}

// MARK: - Extensions

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let usableSessions = sessions {
            return usableSessions.count
        } else {
            print("no sessions")
            return 1
            
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = mindfulSessionsTableView.dequeueReusableCell(withIdentifier: "SessionCell", for: indexPath) as? SessionEntryTableViewCell
        if let usableSessions = sessions {
            // Tiempo de la sesión
            let time = Calendar.current.dateComponents([.minute], from: usableSessions[indexPath.row].startDate, to: usableSessions[indexPath.row].endDate)
            let minutes = time.minute
            cell?.sessionDuration.text = "\(String(describing: minutes!))"

            let dateFormatter = DateFormatter()
            // Fecha de la sesión
            dateFormatter.dateFormat = "dd/MM"
            cell?.sessionDate.text = dateFormatter.string(from: usableSessions[indexPath.row].startDate)

            // Hora de la sesión
            dateFormatter.dateFormat = "HH:mm"
            cell?.sessionTime.text = dateFormatter.string(from: usableSessions[indexPath.row].startDate)

            // Image config
            // Cambiar color a azul si ha sido en las ultimas 24 horas
        } else {
            print("no last sessions")
            let configuration = UIImage.SymbolConfiguration(scale: .medium)
            cell?.sessionImage.image = UIImage(systemName: "xmark.octagon", withConfiguration: configuration)
            cell?.sessionDuration.text = "No session in the last \(Int(sessionsQueryDays)) days"
        }

        return cell!
    }
    
}

extension ViewController: UITableViewDelegate{
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(indexPath.row)
    }
}
