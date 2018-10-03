import Foundation

class GeneralPrefsConroller: NSViewController
{
  @IBOutlet weak var collapsHistoryCheck: NSButton!
  @IBOutlet weak var deemphasizeCheck: NSButton!
  @IBOutlet weak var tabNeverButton: NSButton!
  @IBOutlet weak var tabMultipleButton: NSButton!
  @IBOutlet weak var tabAlwaysButton: NSButton!
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    collapsHistoryCheck.boolValue = UserDefaults.standard.collapseHistory
    deemphasizeCheck.boolValue = UserDefaults.standard.deemphasizeMerges
    
    let tabButton: NSButton
    
    switch UserDefaults.standard.statusInTabs {
      case .never:        tabButton = tabNeverButton
      case .multipleOnly: tabButton = tabMultipleButton
      case .always:       tabButton = tabAlwaysButton
    }
    tabButton.state = .on
  }
  
  @IBAction func collapseHistoryClicked(_ sender: Any)
  {
    UserDefaults.standard.collapseHistory = collapsHistoryCheck.boolValue
  }
  
  @IBAction func deemphasizeClicked(_ sender: Any)
  {
    UserDefaults.standard.deemphasizeMerges = deemphasizeCheck.boolValue
  }
  
  @IBAction func statusInTabClicked(_ sender: NSButton)
  {
    let status: StatusInTabs
    
    switch sender {
      case tabNeverButton:    status = .never
      case tabMultipleButton: status = .multipleOnly
      case tabAlwaysButton:   status = .always
      default: return
    }
    UserDefaults.standard.statusInTabs = status
  }
}
