//
//  ViewController.swift
//  SloMoVideo
//
//  Created by Linda Cobb on 6/19/15.
//  Copyright © 2015 TimesToCome Mobile. All rights reserved.
//

import UIKit
import Accelerate
import AVFoundation



class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate
{
    
    
    // camera stuff
    var session:AVCaptureSession!
    var videoInput : AVCaptureDeviceInput!
    var videoDevice:AVCaptureDevice!

    var fps:Float = 30.0
    
    
    
    
    // used to compute frames per second
    var newDate:NSDate = NSDate()
    var oldDate:NSDate = NSDate()
    
    
    
    // needed to init image context
    var context:CIContext!
    
    


    override func viewDidLoad() {
        super.viewDidLoad()
    }

    
    
    
    // set up to grab live images from the camera
    func setupDevice (){
        
        
        // inputs - find and use back facing camera
        let videoDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)

        for device in videoDevices{
            if device.position == AVCaptureDevicePosition.Back {
                videoDevice = device as! AVCaptureDevice
            }
        }
        
        // set video input to back camera
        do { videoInput = try AVCaptureDeviceInput(device: videoDevice) } catch { return }
        
        
        // supporting formats 240 fps
        var bestFormat = AVCaptureDeviceFormat()
        var bestFrameRate = AVFrameRateRange()
        
        for format in videoDevice.formats {
            let ranges = format.videoSupportedFrameRateRanges as! [AVFrameRateRange]
            
            for range in ranges {
                if range.maxFrameRate >= 240 {
                    bestFormat = format as! AVCaptureDeviceFormat
                    bestFrameRate = range
                }
            }
        }
        
        
        
        
        // set highest fps
        do { try videoDevice.lockForConfiguration()
            
            videoDevice.activeFormat = bestFormat
            
            videoDevice.activeVideoMaxFrameDuration = bestFrameRate.maxFrameDuration
            videoDevice.activeVideoMinFrameDuration = bestFrameRate.minFrameDuration
            
            
            videoDevice.unlockForConfiguration()
        } catch { return }
        
    
        
    }
    
    
    
    
    
    func setupCaptureSession () {
 
        
        
        // set up session
        let dataOutput = AVCaptureVideoDataOutput()
        let sessionQueue = dispatch_queue_create("AVSessionQueue", DISPATCH_QUEUE_SERIAL)
        
        
        dataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        session = AVCaptureSession()
        
        
        // ** need this to override default settings, otherwise reverts to 30fps
        session.sessionPreset = AVCaptureSessionPresetInputPriority
        
        
        
        // turn on light
        session.beginConfiguration()
        
        do { try videoDevice.lockForConfiguration()
            
            do { try videoDevice.setTorchModeOnWithLevel(AVCaptureMaxAvailableTorchLevel )
            } catch { return }      // torch mode
            
            videoDevice.unlockForConfiguration()
            
        } catch  { return }         // lock for config
        
        session.commitConfiguration()
        
        
        
        
        // start session
        session.addInput(videoInput)
        session.addOutput(dataOutput)
        session.startRunning()
        
    }
    

    
    
    
    
    
    // grab each camera image,
    // split into color and brightness
    // processing slows camera down to 12fps
    // need to cut image size and speed up processing
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        
        // calculate our actual fps
        newDate = NSDate()
        fps = 1.0/Float(newDate.timeIntervalSinceDate(oldDate))
        oldDate = newDate
        print("fps \(fps)")
        
        
        // get the image from the camera
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        // lock buffer
        CVPixelBufferLockBaseAddress(imageBuffer!, 0)
        
        
        //*************************************************************************
        // incoming is YUV format - get format info using this
        // let description = CMSampleBufferGetFormatDescription(sampleBuffer)
        //print(description)
        
        
        // 2 planes
        // width, height plane 0
        // width/2, height/2 plane 1
        // bits per block 8
        // CVImageBufferYCbCrMatrix
        
        /*
        // collect brightness data
        let pixelsLuma = 1280 * 720     // Luma buffer (brightness)
        let baseAddressLuma = CVPixelBufferGetBaseAddressOfPlane(imageBuffer!, 0)
        let dataBufferLuma = UnsafeMutablePointer<UInt8>(baseAddressLuma)
        */
        
        
        // collect color data
       // let pixelsChroma = 174 * 144     // Chromiance buffer (color)
       // let baseAddressChroma = CVPixelBufferGetBaseAddressOfPlane(imageBuffer!, 1)
      //  let dataBufferChroma = UnsafeMutablePointer<UInt8>(baseAddressChroma)
        
        // split into U and V colors
        //let pixelsUorVChroma = pixelsChroma / 2
        
        
        
        CVPixelBufferUnlockBaseAddress(imageBuffer!, 0)
        
        
        
        /*
        // get pixel data
        // brightness
        var lumaVector:[Float] = Array(count: pixelsLuma, repeatedValue: 0.0)
        vDSP_vfltu8(dataBufferLuma, 1, &lumaVector, 1, vDSP_Length(pixelsLuma))
        var averageLuma:Float = 0.0
        vDSP_meamgv(&lumaVector, 1, &averageLuma, vDSP_Length(pixelsLuma))
        */
        
        /*
        // pixel color data
        var chromaVector:[Float] = Array(count: pixelsChroma, repeatedValue: 0.0)
        vDSP_vfltu8(dataBufferChroma, 1, &chromaVector, 1, vDSP_Length(pixelsChroma))
        var averageChroma:Float = 0.0
        vDSP_meamgv(&chromaVector, 1, &averageChroma, vDSP_Length(pixelsChroma))
        
        // split color into U/V
        var chromaUVector:[Float] = Array(count: pixelsUorVChroma, repeatedValue: 0.0)  // Cb
        var chromaVVector:[Float] = Array(count: pixelsUorVChroma, repeatedValue: 0.0)  // Cr
        
        vDSP_vfltu8(dataBufferChroma, 2, &chromaUVector, 1, vDSP_Length(pixelsUorVChroma))
        vDSP_vfltu8(dataBufferChroma+1, 2, &chromaVVector, 1, vDSP_Length(pixelsUorVChroma))
        
        var averageUChroma:Float = 0.0
        var averageVChroma:Float = 0.0
        
        vDSP_meamgv(&chromaUVector, 1, &averageUChroma, vDSP_Length(pixelsUorVChroma))
        vDSP_meamgv(&chromaVVector, 1, &averageVChroma, vDSP_Length(pixelsUorVChroma))
        */
        
        
        
        // use this to convert image if the luma/chroma doesn't work ?
        // ? R = Y - 1.403V'
        // B = Y + 1.770U'
        // G = Y - 0.344U' - 0.714V'
        
    }
    
    
    
    //////////////////////////////////////////////////////////////
    // UI start/stop camera
    //////////////////////////////////////////////////////////////
    @IBAction func stop(){
        session.stopRunning()           // stop camera
    }
    
    
    
    @IBAction func start(){
        
        setupDevice()                   // setup camera
        setupCaptureSession()           // start camera
    }
    
    
    
    
    
    
    //////////////////////////////////////////////////////////
    //    cleanup           //////////////////////////////////
    //////////////////////////////////////////////////////////
    override func viewDidDisappear(animated: Bool){
        
        super.viewDidDisappear(animated)
        stop()
    }
    

    
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }


}

