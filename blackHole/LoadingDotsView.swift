import UIKit

final class LoadingDotsView: UIView {
    private let textLabel = UILabel()
    private let dotsStack = UIStackView()
    private var dotLabels: [UILabel] = []
    private var isAnimating = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = UIFont(name: "NDAstroneer-Regular", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .regular)
        textLabel.textColor = .white
        textLabel.text = "LOADING"
        
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        dotsStack.axis = .horizontal
        dotsStack.spacing = 4
        dotsStack.alignment = .bottom
        dotsStack.distribution = .fillEqually
        
        for _ in 0..<3 {
            let dot = UILabel()
            dot.font = UIFont(name: "NDAstroneer-Regular", size: 24) ?? UIFont.systemFont(ofSize: 24)
            dot.textColor = .white
            dot.text = "."
            dot.alpha = 0.2
            dotLabels.append(dot)
            dotsStack.addArrangedSubview(dot)
        }
        
        let container = UIStackView(arrangedSubviews: [textLabel, dotsStack])
        container.translatesAutoresizingMaskIntoConstraints = false
        container.axis = .horizontal
        container.spacing = 6
        container.alignment = .center
        container.distribution = .equalCentering
        addSubview(container)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func setText(_ text: String, animated: Bool) {
        textLabel.text = text
        dotsStack.isHidden = !animated
        if animated {
            startAnimatingDots()
        } else {
            stopAnimatingDots()
        }
    }
    
    func removeFromSuperviewAnimated() {
        stopAnimatingDots()
        removeFromSuperview()
    }
    
    private func startAnimatingDots() {
        guard !isAnimating else { return }
        isAnimating = true
        let baseTime = CACurrentMediaTime()
        for (index, dot) in dotLabels.enumerated() {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.2
            animation.toValue = 1.0
            animation.duration = 0.6
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.beginTime = baseTime + Double(index) * 0.2
            dot.layer.add(animation, forKey: "loadingDot")
        }
    }
    
    private func stopAnimatingDots() {
        guard isAnimating else { return }
        isAnimating = false
        for dot in dotLabels {
            dot.layer.removeAnimation(forKey: "loadingDot")
            dot.alpha = 1.0
        }
    }
}
