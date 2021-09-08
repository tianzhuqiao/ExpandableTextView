import UIKit
import ExpandableTextView

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var tableView: UITableView!
    var data: [String] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        self.tableView = UITableView(frame: self.view.frame)
        self.tableView.register(ExpandableTextViewTableCell.self, forCellReuseIdentifier: "ExpandableTextViewCell")

        tableView.delegate = self
        tableView.dataSource = self
        self.view.addSubview(tableView)

        tableView.backgroundColor = .white
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50
        tableView.tableFooterView = UIView()

        let guide = view.safeAreaLayoutGuide
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: guide.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: guide.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: guide.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true

        data.append("Short text")
        data.append("Link: www.google.com")
        data.append("In post mean shot ye. There out her child sir his lived. Design at uneasy me season of branch on praise esteem. Abilities discourse believing consisted remaining to no. Mistaken no me denoting dashwood as screened. Whence or esteem easily he on. Dissuade husbands at of no if disposal. ")
        data.append("In post mean shot ye. www.google.com. There out her child sir his lived. Design at uneasy me season of branch on praise esteem. Abilities discourse believing consisted remaining to no. Mistaken no me denoting dashwood as screened. Whence or esteem easily he on. Dissuade husbands at of no if disposal. ")
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let dc = self.data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExpandableTextViewCell", for: indexPath) as! ExpandableTextViewTableCell
        cell.data = dc
        return cell
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: nil) { _ in
                self.tableView.reloadData()
            }
    }
}

class ExpandableTextViewTableCell: UITableViewCell, ExpandableTextViewDelegate {

    var data: String? {
        didSet {
            self.notesTextView.text = self.data
        }
    }

    required public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        self.selectionStyle = .default
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func setupView() {
        self.notesTextView.removeFromSuperview()
        self.contentView.addSubview(notesTextView)
        notesTextView.translatesAutoresizingMaskIntoConstraints = false
        notesTextView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
        notesTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
        notesTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20).isActive = true
        notesTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20).isActive = true
    }

    lazy var notesTextView : ExpandableTextView = {
        let v = ExpandableTextView()
        v.font = UIFont(name: "HelveticaNeue", size: 16)
        v.textColor = UIColor(red:0x22/255, green: 0x22/255, blue: 0x22/255, alpha: 1)
        v.backgroundColor = .clear
        v.moreText = "Read More"
        v.lessText = "Read Less"
        v.delegateExppanable = self
        v.numberOfLines = 3
        return v
    }()

    func updateCell() {
        if let tableView = self.tableView {
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }

    func didExpandTextView(_ textView: ExpandableTextView) {
        updateCell()
    }

    func didCollapseTextView(_ textView: ExpandableTextView) {
        updateCell()
    }

    func expandableTextViewUpdateHeight(_ textView: ExpandableTextView) {
        updateCell()
    }
}

extension UITableViewCell {
    /// Search up the view hierarchy of the table view cell to find the containing table view
    var tableView: UITableView? {
        get {
            var table: UIView? = superview
            while !(table is UITableView) && table != nil {
                table = table?.superview
            }

            return table as? UITableView
        }
    }
}
