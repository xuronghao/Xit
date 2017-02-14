import Foundation

class BlameController: XTWebViewController, TabWidthVariable
{
  @IBOutlet var spinner: NSProgressIndicator!
  
  func notAvailable()
  {
    DispatchQueue.main.async {
      [weak self] in
      self?.loadNotice("Blame not available")
    }
  }
  
  func loadBlame(_ text: String, _ path: String, _ model: XTFileChangesModel)
  {
    defer {
      DispatchQueue.main.async {
        [weak self] in
        self?.spinner.isHidden = true
        self?.spinner.stopAnimation(nil)
      }
    }
    
    guard let blame = (model as? Blaming)?.blame(for: path)
    else {
      notAvailable()
      return
    }
    
    var htmlLines = [String]()
    let lines = text.components(separatedBy: .newlines)
    
    for hunk in blame.hunks {
      htmlLines.append(contentsOf: [
        "<tr><td class='blamehead'>\(hunk.finalSignature.name ?? "")</td>",
        "<td>"
        ])
      
      let start = hunk.finalLineStart - 1
      let end = min(start + hunk.lineCount, lines.count-1)
      let hunkLines = lines[start..<end]
      
      htmlLines.append(contentsOf: hunkLines.map {
        "<div class='line'>\(XTWebViewController.escapeText($0))</div>" })
      htmlLines.append("</td></tr>")
    }
    
    let htmlTemplate = XTWebViewController.htmlTemplate("blame")
    let html = String(format: htmlTemplate, htmlLines.joined(separator: "\n"))
    
    DispatchQueue.main.async {
      [weak self] in
      self?.webView?.mainFrame.loadHTMLString(
        html, baseURL: XTWebViewController.baseURL())
    }
  }
}

extension BlameController: XTFileContentController
{
  func clear()
  {
    webView?.mainFrame.loadHTMLString("", baseURL: nil)
  }
  
  public func load(path: String!, model: XTFileChangesModel!, staged: Bool)
  {
    guard let data = model.dataForFile(path, staged: staged),
          let text = String(data: data, encoding: .utf8) ??
                     String(data: data, encoding: .utf16)
    else {
      notAvailable()
      return
    }
    
    spinner.isHidden = false
    spinner.startAnimation(nil)
    clear()
    DispatchQueue.global(qos: .userInitiated).async {
      [weak self] in
      self?.loadBlame(text, path, model)
    }
  }
}
