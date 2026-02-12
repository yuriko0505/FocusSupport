import AppKit

extension SettingsWindowController {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == questionsTableView {
            return questions.count
        }
        return images.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == questionsTableView {
            return makeTextCell(
                tableView: tableView,
                identifier: "questionCell",
                text: questions[row],
                isEditable: true
            )
        }
        return makeTextCell(
            tableView: tableView,
            identifier: "imageCell",
            text: images[row],
            isEditable: false
        )
    }

    func makeTextCell(tableView: NSTableView,
                      identifier: String,
                      text: String,
                      isEditable: Bool) -> NSTableCellView {
        let cellId = NSUserInterfaceItemIdentifier(identifier)
        let cell: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = cellId

            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = isEditable
            textField.usesSingleLineMode = true
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            if isEditable {
                textField.delegate = self
            }

            cell.textField = textField
            cell.addSubview(textField)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: cellVerticalPadding),
                textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -cellVerticalPadding)
            ])
        }
        cell.textField?.isEditable = isEditable
        cell.textField?.stringValue = text
        return cell
    }
}
