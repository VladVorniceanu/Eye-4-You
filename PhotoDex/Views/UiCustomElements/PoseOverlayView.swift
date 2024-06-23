import SwiftUI
import Vision

struct PoseOverlayView: View {
    @Binding var points: [VNHumanBodyPoseObservation.JointName: CGPoint]
    
    let bodyPartConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.rightShoulder, .rightElbow),
        (.leftElbow, .leftWrist), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.rightHip, .rightKnee),
        (.leftKnee, .leftAnkle), (.rightKnee, .rightAnkle)
    ]
    
    let orderedJoints: [VNHumanBodyPoseObservation.JointName] = [
        .neck, .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .root,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(orderedJoints, id: \.self) { key in
                    if let point = points[key] {
                        Circle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 20, height: 20)
                            .position(x: point.x * geometry.size.width, y: point.y * geometry.size.height)
                    }
                }
                
                Path { path in
                    for (jointA, jointB) in bodyPartConnections {
                        if let pointA = points[jointA], let pointB = points[jointB] {
                            path.move(to: CGPoint(x: pointA.x * geometry.size.width, y: pointA.y * geometry.size.height))
                            path.addLine(to: CGPoint(x: pointB.x * geometry.size.width, y: pointB.y * geometry.size.height))
                        }
                    }
                }
                .stroke(Color.gray.opacity(0.5), lineWidth: 10)
                
                ForEach(orderedJoints, id: \.self) { key in
                    if let point = points[key] {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .position(x: point.x * geometry.size.width, y: point.y * geometry.size.height)
                    }
                }
                
                Path { path in
                    for (jointA, jointB) in bodyPartConnections {
                        if let pointA = points[jointA], let pointB = points[jointB] {
                            path.move(to: CGPoint(x: pointA.x * geometry.size.width, y: pointA.y * geometry.size.height))
                            path.addLine(to: CGPoint(x: pointB.x * geometry.size.width, y: pointB.y * geometry.size.height))
                        }
                    }
                }
                .stroke(Color.red, lineWidth: 2)
            }
        }
    }
}
