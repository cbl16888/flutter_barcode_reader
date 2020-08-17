//
//  BarcodeScannerViewController.swift
//  barcode_scan
//
//  Created by Julian Finkler on 20.02.20.
//

import Foundation
import MTBBarcodeScanner

class BarcodeScannerViewController: UIViewController {
  private var previewView: UIView?
  private var scanRect: ScannerOverlay?
  private var scanner: MTBBarcodeScanner?
    
    fileprivate lazy var tipLabel: UILabel = {
        let tipLabel = UILabel()
        tipLabel.font = UIFont.systemFont(ofSize: 14.0)
        tipLabel.textColor = UIColor.white
        tipLabel.textAlignment = .center
        tipLabel.text = "请扫描设备上的二维码"
        tipLabel.numberOfLines = 0
        tipLabel.adjustsFontSizeToFitWidth = true
        return tipLabel
    }()
    
    fileprivate lazy var inputButton: UIButton = {
        let width = 200.0
        let height = 50.0
        let inputButton = UIButton(frame: CGRect(x: (Double(UIScreen.main.bounds.width) - width) * 0.5, y: Double(UIScreen.main.bounds.height) - height - 40.0, width: width, height: height))
        inputButton.setTitle("输入设备号", for: .normal)
        inputButton.titleLabel?.font = UIFont.systemFont(ofSize: 18.0)
        inputButton.layer.cornerRadius = 10.0
        inputButton.layer.masksToBounds = true
        inputButton.backgroundColor = UIColor(red: 87/255, green: 210/255, blue: 200/255, alpha: 1)
        inputButton.addTarget(self, action: #selector(didClickInputButton), for: .touchUpInside)
        return inputButton
    }()
    
    fileprivate lazy var openButton: UIButton = {
        let width = 200.0
        let height = 50.0
        let openButton = UIButton(frame: CGRect(x: (Double(UIScreen.main.bounds.width) - width) * 0.5, y: Double(self.tipLabel.bounds.maxY) + 20.0, width: width, height: height))
        openButton.isHidden = true
        openButton.setTitle("立即启用", for: .normal)
        openButton.titleLabel?.font = UIFont.systemFont(ofSize: 18.0)
        openButton.layer.cornerRadius = 10.0
        openButton.layer.masksToBounds = true
        openButton.backgroundColor = UIColor(red: 87/255, green: 210/255, blue: 200/255, alpha: 1)
        openButton.addTarget(self, action: #selector(didClickOpenButton), for: .touchUpInside)
        return openButton
    }()
  
  var config: Configuration = Configuration.with {
    $0.strings = [
      "cancel" : "Cancel",
      "flash_on" : "Flash on",
      "flash_off" : "Flash off",
    ]
    $0.useCamera = -1 // Default camera
    $0.autoEnableFlash = false
  }
  
  private let formatMap = [
    BarcodeFormat.aztec : AVMetadataObject.ObjectType.aztec,
    BarcodeFormat.code39 : AVMetadataObject.ObjectType.code39,
    BarcodeFormat.code93 : AVMetadataObject.ObjectType.code93,
    BarcodeFormat.code128 : AVMetadataObject.ObjectType.code128,
    BarcodeFormat.dataMatrix : AVMetadataObject.ObjectType.dataMatrix,
    BarcodeFormat.ean8 : AVMetadataObject.ObjectType.ean8,
    BarcodeFormat.ean13 : AVMetadataObject.ObjectType.ean13,
    BarcodeFormat.interleaved2Of5 : AVMetadataObject.ObjectType.interleaved2of5,
    BarcodeFormat.pdf417 : AVMetadataObject.ObjectType.pdf417,
    BarcodeFormat.qr : AVMetadataObject.ObjectType.qr,
    BarcodeFormat.upce : AVMetadataObject.ObjectType.upce,
  ]
  
  var delegate: BarcodeScannerViewControllerDelegate?
  
  private var device: AVCaptureDevice? {
    return AVCaptureDevice.default(for: .video)
  }
  
  private var isFlashOn: Bool {
    return device != nil && (device?.flashMode == AVCaptureDevice.FlashMode.on || device?.torchMode == .on)
  }
  
  private var hasTorch: Bool {
    return device?.hasTorch ?? false
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if targetEnvironment(simulator)
    view.backgroundColor = .lightGray
    #endif
    
    previewView = UIView(frame: view.bounds)
    if let previewView = previewView {
      previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(previewView)
    }
    setupScanRect(view.bounds)
    view.addSubview(tipLabel)
    view.addSubview(inputButton)
    view.addSubview(openButton)
    let rect = scanRect!.scanLineRect
    tipLabel.frame = CGRect(x: rect.origin.x, y: rect.origin.y + rect.size.width * 0.5 + 10, width: rect.size.width, height: 40.0)
    openButton.frame = CGRect(x: openButton.frame.minX, y: rect.origin.y - openButton.frame.height * 0.5, width: openButton.frame.width, height: openButton.frame.height)
    let restrictedBarcodeTypes = mapRestrictedBarcodeTypes()
    if restrictedBarcodeTypes.isEmpty {
      scanner = MTBBarcodeScanner(previewView: previewView)
    } else {
      scanner = MTBBarcodeScanner(metadataObjectTypes: restrictedBarcodeTypes,
                                  previewView: previewView
      )
    }
    
    let backButton = UIButton(type: .custom)
    backButton.frame = CGRect(x: 0, y: 0, width: 20.0, height: 20.0)
    if var bundleURL = Bundle.main.url(forResource: "Frameworks", withExtension: nil) {
        bundleURL = bundleURL.appendingPathComponent("barcode_scan")
        bundleURL = bundleURL.appendingPathExtension("framework")
        if let bundle = Bundle(url: bundleURL) {
            if let imagePath = bundle.path(forResource: "back_icon.png", ofType: nil) {
                let backImage = UIImage(contentsOfFile: imagePath)
                backButton.setImage(backImage, for: .normal)
            }
        }
        
    }
    backButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
    updateToggleFlashButton()
  }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationController?.navigationBar.shadowImage = UIImage()
    }
    
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    if scanner!.isScanning() {
      scanner!.stopScanning()
    }
    
    scanRect?.startAnimating()
    MTBBarcodeScanner.requestCameraPermission(success: { [weak self] success in
      if success {
        self?.startScan()
        self?.openButton.isHidden = true
        self?.tipLabel.text = "请扫描设备上的二维码"
      } else {
//        #if !targetEnvironment(simulator)
//        self.errorResult(errorCode: "PERMISSION_NOT_GRANTED")
//        #endif
        self?.tipLabel.text = "相机权限已被禁用，无法使用二维码的扫描功能，点击\"立即启用\"打开它"
        self?.openButton.isHidden = false
      }
    })
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    scanner?.stopScanning()
    scanRect?.stopAnimating()
    
    if isFlashOn {
      setFlashState(false)
    }
    
    super.viewWillDisappear(animated)
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    setupScanRect(CGRect(origin: CGPoint(x: 0, y:0),
                         size: size
    ))
  }
  
  private func setupScanRect(_ bounds: CGRect) {
    if scanRect != nil {
      scanRect?.stopAnimating()
      scanRect?.removeFromSuperview()
    }
    scanRect = ScannerOverlay(frame: bounds)
    if let scanRect = scanRect {
      scanRect.translatesAutoresizingMaskIntoConstraints = false
      scanRect.backgroundColor = UIColor.clear
      view.addSubview(scanRect)
      scanRect.startAnimating()
    }
  }
  
  private func startScan() {
    do {
      try scanner!.startScanning(with: cameraFromConfig, resultBlock: { codes in
        if let code = codes?.first {
          let codeType = self.formatMap.first(where: { $0.value == code.type });
          let scanResult = ScanResult.with {
            $0.type = .barcode
            $0.rawContent = code.stringValue ?? ""
            $0.format = codeType?.key ?? .unknown
            $0.formatNote = codeType == nil ? code.type.rawValue : ""
          }
          self.scanner!.stopScanning()
          self.scanResult(scanResult)
        }
      })
      if(config.autoEnableFlash){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
          self.setFlashState(true)
        }
      }
    } catch {
      self.scanResult(ScanResult.with {
        $0.type = .error
        $0.rawContent = "\(error)"
        $0.format = .unknown
      })
    }
  }
  
  @objc private func cancel() {
    self.scanResult(ScanResult.with {
      $0.type = .error
      $0.format = .unknown
    })
  }
  
  @objc private func onToggleFlash() {
    setFlashState(!isFlashOn)
  }
    
    @objc private func didClickInputButton() {
        scanResult( ScanResult.with {
          $0.type = .cancelled
          $0.format = .unknown
        });
    }
    
    @objc private func didClickOpenButton() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if (UIApplication.shared.canOpenURL(url)) {
                UIApplication.shared.openURL(url)
            }
        }
    }
  
  private func updateToggleFlashButton() {
    if !hasTorch {
      return
    }
    
//    let buttonText = isFlashOn ? config.strings["flash_off"] : config.strings["flash_on"]
//    navigationItem.rightBarButtonItem = UIBarButtonItem(title: buttonText,
//                                                        style: .plain,
//                                                        target: self,
//                                                        action: #selector(onToggleFlash)
//    )
  }
  
  private func setFlashState(_ on: Bool) {
    if let device = device {
      guard device.hasFlash && device.hasTorch else {
        return
      }
      
      do {
        try device.lockForConfiguration()
      } catch {
        return
      }
      
      device.flashMode = on ? .on : .off
      device.torchMode = on ? .on : .off
      
      device.unlockForConfiguration()
      updateToggleFlashButton()
    }
  }
  
  private func errorResult(errorCode: String){
    delegate?.didFailWithErrorCode(self, errorCode: errorCode)
    dismiss(animated: false)
  }
  
  private func scanResult(_ scanResult: ScanResult){
    self.delegate?.didScanBarcodeWithResult(self, scanResult: scanResult)
    dismiss(animated: false)
  }
  
  private func mapRestrictedBarcodeTypes() -> [String] {
    var types: [AVMetadataObject.ObjectType] = []
    
    config.restrictFormat.forEach({ format in
      if let mappedFormat = formatMap[format]{
        types.append(mappedFormat)
      }
    })
    
    return types.map({ t in t.rawValue})
  }
  
  private var cameraFromConfig: MTBCamera {
    return config.useCamera == 1 ? .front : .back
  }
}
