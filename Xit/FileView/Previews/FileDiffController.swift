import Cocoa

protocol HunkStaging: AnyObject
{
  func stage(hunk: DiffHunk)
  func unstage(hunk: DiffHunk)
  func discard(hunk: DiffHunk)
}

/// Manages a WebView for displaying text file diffs.
class FileDiffController: WebViewController,
                          WhitespaceVariable,
                          ContextVariable
{
  // swiftlint:disable:next weak_delegate
  let actionDelegate: DiffActionDelegate = DiffActionDelegate()
  weak var stagingDelegate: HunkStaging?
  var stagingType: StagingType = .none
  var patch: Patch?
  
  fileprivate var isLoaded_internal = false
  
  public var whitespace = PreviewsPrefsController.Default.whitespace()
  {
    didSet { configureDiffMaker() }
  }
  public var contextLines = PreviewsPrefsController.Default.contextLines()
  {
    didSet { configureDiffMaker() }
  }
  var diffMaker: PatchMaker?
  {
    didSet { configureDiffMaker() }
  }

  override func viewDidLoad()
  {
    actionDelegate.controller = self
  }
  
  override func wrappingWidthAdjustment() -> Int
  {
    return 12
  }

  private func configureDiffMaker()
  {
    diffMaker?.whitespace = whitespace
    diffMaker?.contextLines = contextLines
    reloadDiff()
  }

  static func hunkLine(diffLine text: String,
                       oldLine: Int32,
                       newLine: Int32) -> String
  {
    var className = "pln"
    var oldLineText = ""
    var newLineText = ""
    let escaped = text.xmlEscaped
    
    if oldLine == -1 {
      className = "add"
    }
    else {
      oldLineText = "\(oldLine)"
    }
    if newLine == -1 {
      className = "del"
    }
    else {
      newLineText = "\(newLine)"
    }
    return """
        <div class=\(className)>\
        <span class='old' line='\(oldLineText)'></span>\
        <span class='new' line='\(newLineText)'></span>\
        <span class='text'>\(escaped)</span>\
        </div>
        """
  }
  
  func button(title: UIString, action: String, index: Int) -> String
  {
    return "<span class='hunkbutton' " +
           "onClick='window.webActionDelegate.\(action)(\(index))'" +
           ">\(title.rawValue)</span>"
  }
  
  func hunkHeader(hunk: DiffHunk, index: Int, lines: [String]?) -> String
  {
    guard stagingType != .none,
          let diffMaker = diffMaker
    else { return "" }
    
    var header = "<div class='hunkhead'>\n"
    
    if lines.map({ hunk.canApply(to: $0) }) ?? false {
      switch stagingType {
        case .index:
          header += button(title: .unstage, action: "unstageHunk",
                           index: index)
        case .workspace:
          header += button(title: .stage, action: "stageHunk",
                           index: index)
          header += button(title: .discard, action: "discardHunk",
                           index: index)
        default: break
      }
    }
    else {
      let notice: UIString = (diffMaker.whitespace == .showAll)
                   ? .cantApplyHunk
                   : .whitespaceChangesHidden
      
      header += "<span class='hunknotice'>\(notice.rawValue)</span>"
    }
    header += "</div>\n"
    
    return header
  }
  
  /// Returns the index/workspace counterpart blob
  func diffTargetBlob() -> Blob?
  {
    let window = Thread.syncOnMainThread { view.window }
    // TODO: Give it access to the repository via the FileContents protocol
    let repo = (window?.windowController as! XTWindowController)
      .xtDocument!.repository!
    guard let diffMaker = diffMaker,
          let headRef = repo.headRef
    else { return nil }

    switch stagingType {
      case .none:
        return nil
      case .index:
        return repo.fileBlob(ref: headRef, path: diffMaker.path)
      case .workspace:
        return repo.stagedBlob(file: diffMaker.path)
    }
  }
  
  func reloadDiff()
  {
    guard let diffMaker = diffMaker,
          let patch = diffMaker.makePatch()
    else {
      self.patch = nil
      return
    }
    let htmlTemplate = WebViewController.htmlTemplate("diff")
    var textLines = [String]()
    
    self.patch = patch
    
    guard patch.hunkCount > 0
    else {
      loadNoChangesNotice()
      return
    }
    
    var lines: [String]?
    
    if let blob = diffTargetBlob() {
      _ = try? blob.withData {
        (data) in
        var encoding = String.Encoding.utf8
        let text = String(data: data, usedEncoding: &encoding)
        
        lines = text?.components(separatedBy: .newlines)
      }
    }
    
    for index in 0..<patch.hunkCount {
      guard let hunk = patch.hunk(at: index)
      else { continue }
      
      textLines.append(hunkHeader(hunk: hunk, index: index, lines: lines))
      textLines.append("<div class='hunk'>")
      hunk.enumerateLines {
        (line) in
        textLines.append(FileDiffController.hunkLine(diffLine: line.text,
                                                       oldLine: line.oldLine,
                                                       newLine: line.newLine))
      }
      textLines.append("</div>")
    }
    
    let joined = textLines.joined(separator: "\n")
    let html = htmlTemplate.replacingOccurrences(of: "%@", with: joined)
    
    load(html: html)
    isLoaded = true
  }
  
  func loadOrNotify(diffResult: PatchMaker.PatchResult?)
  {
    if let diffResult = diffResult {
      switch diffResult {
        case .noDifference:
          loadNoChangesNotice()
        case .binary:
          loadNotice(.binaryFile)
        case .diff(let diffMaker):
          self.diffMaker = diffMaker
      }
    }
    else {
      loadNoChangesNotice()
    }
  }
  
  func loadNoChangesNotice()
  {
    var notice: UIString
    
    switch stagingType {
      case .none:
        notice = .noChanges
      case .index:
        notice = .noStagedChanges
      case .workspace:
        notice = .noUnstagedChanges
    }
    loadNotice(notice)
  }
  
  func hunk(at index: Int) -> DiffHunk?
  {
    guard let patch = self.patch,
          (index >= 0) && (UInt(index) < patch.hunkCount)
    else { return nil }
    
    return patch.hunk(at: index)
  }
  
  func stageHunk(index: Int)
  {
    hunk(at: index).map { stagingDelegate?.stage(hunk: $0) }
  }
  
  func unstageHunk(index: Int)
  {
    hunk(at: index).map { stagingDelegate?.unstage(hunk: $0) }
  }
  
  func discardHunk(index: Int)
  {
    NSAlert.confirm(message: .confirmDiscardHunk,
                    actionName: .discard,
                    parentWindow: view.window!) {
      guard let hunk = self.hunk(at: index)
      else { return }
      
      self.stagingDelegate?.discard(hunk: hunk)
    }
  }
}

extension FileDiffController: WebActionDelegateHost
{
  var webActionDelegate: Any
  {
    return actionDelegate
  }
}

extension FileDiffController: XTFileContentController
{
  var isLoaded: Bool
  {
    get
    {
      return withSync { isLoaded_internal }
    }
    set
    {
      withSync {
        isLoaded_internal = newValue
      }
    }
  }

  public func clear()
  {
    load(html: "")
    isLoaded = false
  }
  
  public func load(selection: [FileSelection])
  {
    switch selection.count {
      case 0:
        clear()
        return
      case 1:
        self.stagingType = selection[0].staging
        loadOrNotify(diffResult:
            selection[0].fileList.diffForFile(selection[0].path))
      default:
        loadNotice(.multipleItemsSelected)
    }
  }
}

class DiffActionDelegate: NSObject
{
  weak var controller: FileDiffController!
  
  override class func isSelectorExcluded(fromWebScript selector: Selector) -> Bool
  {
    switch selector {
      case #selector(DiffActionDelegate.stageHunk(index:)),
           #selector(DiffActionDelegate.unstageHunk(index:)),
           #selector(DiffActionDelegate.discardHunk(index:)):
        return false
      default:
        return true
    }
  }
  
  override class func webScriptName(for selector: Selector) -> String
  {
    switch selector {
      case #selector(DiffActionDelegate.stageHunk(index:)):
        return "stageHunk"
      case #selector(DiffActionDelegate.unstageHunk(index:)):
        return "unstageHunk"
      case #selector(DiffActionDelegate.discardHunk(index:)):
        return "discardHunk"
      default:
        return ""
    }
  }
  
  @objc func stageHunk(index: Int)
  {
    controller.stageHunk(index: index)
  }
  
  @objc func unstageHunk(index: Int)
  {
    controller.unstageHunk(index: index)
  }
  
  @objc func discardHunk(index: Int)
  {
    controller.discardHunk(index: index)
  }
}
