//
//  IDPhotoAutoRotateVC.swift
//  MyApp
//
//  Created by 黄瑞 on 2022/11/18.
//

import UIKit

class IDPhotoAutoRotateVC: UIViewController {
    let alpha = 0.0
    
    lazy var mouse_view = {
        let view = UIView(frame: .init(origin: .zero, size: .init(width: 2, height: 2)))
        view.backgroundColor = .red.withAlphaComponent(alpha)
        return view
    }()

    lazy var left_eye_view = {
        let view = UIView(frame: .init(origin: .zero, size: .init(width: 2, height: 2)))
        view.backgroundColor = .red.withAlphaComponent(alpha)
        return view
    }()

    lazy var right_eye_view = {
        let view = UIView(frame: .init(origin: .zero, size: .init(width: 2, height: 2)))
        view.backgroundColor = .red.withAlphaComponent(alpha)
        return view
    }()

    lazy var face_center_view = {
        let view = UIView(frame: .init(origin: .zero, size: .init(width: 2, height: 2)))
        view.backgroundColor = .green.withAlphaComponent(alpha)
        return view
    }()
    
    lazy var image_view = {
        let view = UIImageView()
        view.layer.borderColor = UIColor.red.cgColor
        view.layer.borderWidth = 1
        view.contentMode = .scaleAspectFit
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        view.addSubview(image_view)
        image_view.addSubview(mouse_view)
        image_view.addSubview(left_eye_view)
        image_view.addSubview(right_eye_view)
        image_view.addSubview(face_center_view)
        image_view.isUserInteractionEnabled = true
        image_view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.on_pick_tap(_:))))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        image_view.frame = self.view.bounds
    }

    @objc func on_pick_tap(_ sender: UIButton) {
        image_view.transform = CGAffineTransformIdentity
        let picker = UIImagePickerController()
        picker.delegate = self
        self.present(picker, animated: true)
    }
}

extension IDPhotoAutoRotateVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let url = info[.imageURL] as? URL else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        guard let image = UIImage(data: data) else { return }

        image_view.image = image

        guard let ci_image = CIImage(image: image) else { return }
        guard let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil) else { return }
        guard let features = detector.features(in: ci_image) as? [CIFaceFeature] else { return }

        if let face = features.first {
            let image_ratio = image.size.width / image.size.height
            let image_view_ratio = image_view.frame.width / image_view.frame.height
            let image_scale_size = CGSize(width: image_ratio > image_view_ratio ? image_view.frame.width : image_ratio * image_view.frame.height,
                                          height: image_ratio > image_view_ratio ? image_view.frame.width / image_ratio : image_view.frame.height)
            let image_origin = CGPoint(x: image_ratio > image_view_ratio ? 0 : (image_view.frame.width - image_scale_size.width) / 2,
                                       y: image_ratio > image_view_ratio ? (image_view.frame.height - image_scale_size.height) / 2 : 0)

            // 标准坐标 [0.0, 0.0] ~ [1.0, 1.0]
            let mouse_position = CGPoint(x: face.mouthPosition.x / image.size.width,
                                         y: face.mouthPosition.y / image.size.height)
            let left_eye_position = CGPoint(x: face.leftEyePosition.x / image.size.width,
                                            y: face.leftEyePosition.y / image.size.height)
            let right_eye_position = CGPoint(x: face.rightEyePosition.x / image.size.width,
                                             y: face.rightEyePosition.y / image.size.height)


            mouse_view.center = .init(x: image_origin.x + mouse_position.x * image_scale_size.width,
                                      y: image_origin.y + (1.0 - mouse_position.y) * image_scale_size.height)
            left_eye_view.center = .init(x: image_origin.x + left_eye_position.x * image_scale_size.width,
                                         y: image_origin.y + (1.0 - left_eye_position.y) * image_scale_size.height)
            right_eye_view.center = .init(x: image_origin.x + right_eye_position.x * image_scale_size.width,
                                          y: image_origin.y + (1.0 - right_eye_position.y) * image_scale_size.height)
            
            // 旋转
            let angle = atan((left_eye_view.center.y - right_eye_view.center.y) / (right_eye_view.center.x - left_eye_view.center.x))
            
            // 缩放
            // 眼距
            let eye_distance = sqrt(pow(left_eye_view.center.x - right_eye_view.center.x, 2) + pow(left_eye_view.center.y - right_eye_view.center.y, 2))
            // 目标眼距
            let target_eye_distance = self.view.frame.width / 3
            let scale = target_eye_distance / eye_distance

            // 平移
            // 脸部中心
            let face_center = self.get_triangle_center_of_gravity(p1: mouse_view.center, p2: left_eye_view.center, p3: right_eye_view.center)
            face_center_view.center = face_center
            // 目标中心点
            let target_center = self.view.convert(CGPoint(x: self.view.frame.width / 2, y: self.view.frame.height / 2), to: image_view)
            let offset = CGPoint(x: target_center.x - face_center.x, y: target_center.y - face_center.y)

            var transform = CGAffineTransformIdentity
            transform = transform.concatenating(.init(rotationAngle: angle))
            transform = transform.concatenating(.init(scaleX: scale, y: scale))
            transform = transform.concatenating(.init(translationX: (offset.x * scale) * cos(angle) - (offset.y * scale) * sin(angle),
                                                      y: (offset.x * scale) * sin(angle) + (offset.y * scale) * cos(angle)))
            image_view.transform = transform

        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func get_triangle_center_of_gravity(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        // p1 p2 中点
        let a = CGPoint(x: p1.x + (p2.x - p1.x) / 2, y: p1.y + (p2.y - p1.y) / 2)
        let k_p3_a = (a.y - p3.y) / (a.x - p3.x)
        let center = CGPoint(x: p3.x + (a.x - p3.x) / 3.0 * 2.0, y: p3.y + (a.x - p3.x) / 3.0 * 2.0 * k_p3_a)
        return center
    }
}
