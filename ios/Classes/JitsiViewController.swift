import UIKit
import JitsiMeetSDK
import Flutter

struct SelectedPoint {
  var id: Int
  var name: String
  var cgPoint: CGPoint
}

class JitsiViewController: UIViewController {


    @IBOutlet weak var videoButton: UIButton?

    fileprivate var pipViewCoordinator: PiPViewCoordinator?
    fileprivate var jitsiMeetView: JitsiMeetView?

  static var selectedData: [SelectedPoint] = [] {
    didSet {
      addPointsView()
    }
  }

  private static var transaparentView = UIView()
  var pointerMode: Bool = false
  let pointerModeButton = UIButton()

    var eventSink:FlutterEventSink? = nil
    var roomName:String? = nil
    var serverUrl:URL? = nil
    var subject:String? = nil
    var audioOnly:Bool? = false
    var audioMuted: Bool? = false
    var videoMuted: Bool? = false
    var token:String? = nil
    var featureFlags: Dictionary<String, Any>? = Dictionary();


    var jistiMeetUserInfo = JitsiMeetUserInfo()

    override func loadView() {

        super.loadView()
    }

    @objc func openButtonClicked(sender : UIButton){

        //openJitsiMeetWithOptions();
    }

    @objc func closeButtonClicked(sender : UIButton){
        cleanUp();
        self.dismiss(animated: true, completion: nil)
    }

    override func viewDidLoad() {
        //print("VIEW DID LOAD")
        self.view.backgroundColor = .black
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        openJitsiMeet();
      designUpperView()
    }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.view.bringSubviewToFront(JitsiViewController.transaparentView)
  }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let rect = CGRect(origin: CGPoint.zero, size: size)
        pipViewCoordinator?.resetBounds(bounds: rect)
    }

    func openJitsiMeet() {
        cleanUp()
        // create and configure jitsimeet view
        let jitsiMeetView = JitsiMeetView()


        jitsiMeetView.delegate = self
        self.jitsiMeetView = jitsiMeetView
        let options = JitsiMeetConferenceOptions.fromBuilder { (builder) in
            builder.welcomePageEnabled = true
            builder.room = self.roomName
            builder.serverURL = self.serverUrl
            builder.subject = self.subject
            builder.userInfo = self.jistiMeetUserInfo
            builder.audioOnly = self.audioOnly ?? false
            builder.audioMuted = self.audioMuted ?? false
            builder.videoMuted = self.videoMuted ?? false
            builder.token = self.token

            self.featureFlags?.forEach{ key,value in
                builder.setFeatureFlag(key, withValue: value);
            }
            builder.setFeatureFlag("video-share.enabled", withBoolean: false)
            builder.setFeatureFlag("call-integration.enabled", withBoolean: false)
        }

        jitsiMeetView.join(options)

        // Enable jitsimeet view to be a view that can be displayed
        // on top of all the things, and let the coordinator to manage
        // the view state and interactions
        pipViewCoordinator = PiPViewCoordinator(withView: jitsiMeetView)
        pipViewCoordinator?.configureAsStickyView(withParentView: view)

        // animate in
        jitsiMeetView.alpha = 0
        pipViewCoordinator?.show()
    }

    func closeJitsiMeeting(){
        jitsiMeetView?.leave()
    }

    fileprivate func cleanUp() {
        jitsiMeetView?.removeFromSuperview()
        jitsiMeetView = nil
        pipViewCoordinator = nil
        //self.dismiss(animated: true, completion: nil)
    }
}

extension JitsiViewController: JitsiMeetViewDelegate {

    func conferenceWillJoin(_ data: [AnyHashable : Any]!) {
        //        print("CONFERENCE WILL JOIN")
        var mutatedData = data
        mutatedData?.updateValue("onConferenceWillJoin", forKey: "event")
        self.eventSink?(mutatedData)
    }

    func conferenceJoined(_ data: [AnyHashable : Any]!) {
        //        print("CONFERENCE JOINED")
        var mutatedData = data
        mutatedData?.updateValue("onConferenceJoined", forKey: "event")
        self.eventSink?(mutatedData)
    }

    func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        //        print("CONFERENCE TERMINATED")
        var mutatedData = data
        mutatedData?.updateValue("onConferenceTerminated", forKey: "event")
        self.eventSink?(mutatedData)

        DispatchQueue.main.async {
            self.pipViewCoordinator?.hide() { _ in
                self.cleanUp()
                self.dismiss(animated: true, completion: nil)
            }
        }

    }

    func enterPicture(inPicture data: [AnyHashable : Any]!) {
        //        print("CONFERENCE PIP IN")
        var mutatedData = data
        mutatedData?.updateValue("onPictureInPictureWillEnter", forKey: "event")
        self.eventSink?(mutatedData)
        DispatchQueue.main.async {
            self.pipViewCoordinator?.enterPictureInPicture()
        }
    }

    func exitPictureInPicture() {
        //        print("CONFERENCE PIP OUT")
        var mutatedData : [AnyHashable : Any]
        mutatedData = ["event":"onPictureInPictureTerminated"]
        self.eventSink?(mutatedData)
    }
}

// extension for pointer part
extension JitsiViewController {
  private func designUpperView() {
    designTransparentView()
    JitsiViewController.addPointsView()
    configurePointerCaseButton()
  }

  private func designTransparentView() {
    var transparentViewFrame = CGRect(x: 0, y:0, width:0, height:0)
    transparentViewFrame.size.height = UIScreen.main.bounds.height
    transparentViewFrame.size.width = UIScreen.main.bounds.width
    JitsiViewController.transaparentView.frame = transparentViewFrame
    JitsiViewController.transaparentView.isOpaque = true
    JitsiViewController.transaparentView.isUserInteractionEnabled = pointerMode
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(tapGestureRecognizer:)))
    JitsiViewController.transaparentView.addGestureRecognizer(tapGestureRecognizer)
    self.jitsiMeetView?.addSubview(JitsiViewController.transaparentView)
  }

  private static func addPointsView() {
    for i in JitsiViewController.selectedData {
      removePointIfNeeded(with: i.id)
      drawPointView(name: i.name, id: i.id, point: i.cgPoint)
    }
  }

  private func configurePointerCaseButton() {
    configurePointerButtonApperance()
    pointerModeButton.setTitle("Pointer", for: .normal)
    pointerModeButton.titleLabel?.font = .systemFont(ofSize: 14)
    pointerModeButton.setTitleColor(.blue, for: .normal)
    pointerModeButton.backgroundColor = .white
    pointerModeButton.addTarget(self, action: #selector(pointerButtonPressed), for: .touchUpInside)
    pointerModeButton.translatesAutoresizingMaskIntoConstraints = false
    jitsiMeetView?.addSubview(pointerModeButton)
    pointerModeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8).isActive = true
    pointerModeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4).isActive = true
    pointerModeButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
    pointerModeButton.widthAnchor.constraint(equalToConstant: 70).isActive = true
    pointerModeButton.layer.cornerRadius = 10
  }

  @objc func pointerButtonPressed() {
    pointerMode.toggle()
    JitsiViewController.transaparentView.isUserInteractionEnabled = pointerMode
    configurePointerButtonApperance()
  }

  private func configurePointerButtonApperance() {
    if pointerMode {
      pointerModeButton.setTitleColor(.white, for: .normal)
      pointerModeButton.backgroundColor = .blue
    } else {
      pointerModeButton.setTitleColor(.blue, for: .normal)
      pointerModeButton.backgroundColor = .white
    }
  }

  private static func drawPointView(name: String, id: Int, point: CGPoint) {
    let pointView = UIView()
    var pointViewFrame = CGRect(x: point.x, y:point.y, width:0, height:0)
    pointViewFrame.size.height = 45
    pointViewFrame.size.width = 35
    pointView.frame = pointViewFrame
    pointView.backgroundColor = .lightGray
    pointView.tag = id
    let imageView = UIImageView()
    imageView.heightAnchor.constraint(equalToConstant: 25.0).isActive = true
    imageView.image = UIImage(named: "clicker")
    let textLabel = UILabel()
    imageView.heightAnchor.constraint(equalToConstant: 25.0).isActive = true
    textLabel.text  = name
    textLabel.font = .systemFont(ofSize: 14)
    textLabel.textAlignment = .center
    let stackView = UIStackView()
    stackView.axis = NSLayoutConstraint.Axis.vertical
    stackView.distribution  = UIStackView.Distribution.equalSpacing
    stackView.alignment = UIStackView.Alignment.center
    stackView.spacing = 0.0
    stackView.addArrangedSubview(imageView)
    stackView.addArrangedSubview(textLabel)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    pointView.addSubview(stackView)
    NSLayoutConstraint.activate([
        stackView.topAnchor.constraint(equalTo: pointView.topAnchor),
        stackView.leftAnchor.constraint(equalTo: pointView.leftAnchor),
        stackView.rightAnchor.constraint(equalTo: pointView.rightAnchor),
        stackView.bottomAnchor.constraint(equalTo: pointView.bottomAnchor)
    ])
    transaparentView.addSubview(pointView)
    pointView.layer.cornerRadius = 8
  }

  @objc func viewTapped(tapGestureRecognizer: UITapGestureRecognizer)
  {
    let cgpoint = tapGestureRecognizer.location(in: JitsiViewController.transaparentView)
    JitsiViewController.removePointIfNeeded(with: -1)
    JitsiViewController.drawPointView(name: "ME", id: -1, point: cgpoint)
    let arguments = ["x": cgpoint.x, "y": cgpoint.y] as [String : Any]
    batteryChannel.invokeMethod("iOSUserPoint", arguments: arguments)
  }

  private static func removePointIfNeeded(with id: Int) {
    for subView in transaparentView.subviews where subView.tag == id {
      subView.removeFromSuperview()
    }
  }
}
