//
//  DepictionButtonView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import UIKit

class DepictionButtonView: DepictionBaseView {
    private var button: DepictionButton
    private var subView: DepictionBaseView?

    private var action: String
    private var backupAction: String

    private var yPadding: CGFloat

    private let openExternal: Bool
    private let isLink: Bool

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let action = dictionary["action"] as? String else {
            return nil
        }

        yPadding = (dictionary["yPadding"] as? CGFloat) ?? 0
        button = DepictionButton(type: .custom)

        self.action = action
        backupAction = (dictionary["backupAction"] as? String) ?? ""
        openExternal = (dictionary["openExternal"] as? Bool) ?? false
        isLink = (dictionary["isLink"] as? Bool) ?? false

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)

        var depictView: DepictionBaseView?
        if let dict = dictionary["view"] as? [String: Any] {
            let color = isLink ? tintColor : .white
            depictView = DepictionBaseView.view(dictionary: dict, viewController: viewController, tintColor: color, isActionable: true)
        }

        if let depictView {
            depictView.isUserInteractionEnabled = false
            subView = depictView

            button.depictionView = depictView
            button.addSubview(depictView)
        } else if let text = dictionary["text"] as? String {
            button.setTitle(text, for: .normal)
        }

        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        if !isLink {
            button.layer.cornerRadius = 10
        }
        button.addTarget(self, action: #selector(DepictionButtonView.buttonTapped), for: .touchUpInside)

        button.isLink = isLink
        addSubview(button)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        let rawHeight = subView?.depictionHeight(width: width) ?? (isLink ? 30 : 40)
        return rawHeight + (isLink ? 0 : 16) + (yPadding * 2)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        button.isHighlighted = button.isHighlighted
        if isLink {
            button.frame = bounds
        } else {
            button.frame = bounds.insetBy(dx: 8, dy: 8)
        }
        subView?.frame = button.bounds
    }

    @objc func buttonTapped(_: Any?) {
        if !processAction(action) {
            processAction(backupAction)
        }
    }

    @discardableResult func processAction(_ action: String) -> Bool {
        if action.isEmpty {
            return false
        }
        return DepictionButton.processAction(action, parentViewController: parentViewController, openExternal: openExternal)
    }
}
