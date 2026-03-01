/*
  Use this script to customize documentation lookups in CodeRunner.
  The script is loaded along with the web page when performing a lookup.
  The variable CodeRunnerDocsContext will contain information about the lookup.
  Most fields may also be used in the lookup URL, e.g. {query}, {lang}, etc
  Some important fields include:
  CodeRunnerDocsContext = {
    "query": the documentation search query,
    "lang": language name based on the current editor scope (if in doubt, use this),
    "languageName": active CodeRunner language name,
    "codeCompletionObject": if set, the code completion that invoked the lookup,
    "editorObject": if set, the editor context that invoked the lookup,
    "scope": the editor syntax scope for the current document
  }
  View the full contents of the variable using the code below:
    alert(JSON.stringify(CodeRunnerDocsContext, null, '\t'));

  You may also optionally define the function CodeRunnerDocsContextUpdate(),
  which will be called for consecutive lookups instead of reloading the entire
  page, given that the function returns true.
*/

document.addEventListener('DOMContentLoaded', function (e) {
	if (CodeRunnerDocsContext["isHistoryItem"] == true) {
		return
	}
	window.location.hash = 'content'
	if (CodeRunnerDocsContext["codeCompletionObject"] == null && CodeRunnerDocsContext["editorObject"] == null) {
		return
	}
	var results = document.querySelectorAll('ul.result-list h4 a')
	var query = CodeRunnerDocsContext["query"]
	var escapedQuery = query.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")
	var regex = new RegExp('(\\b|^)('+escapedQuery+')(\\(\\))?$', 'i')
	var matchedResult = false;
	for (var i = 0; i < results.length; i++) {
		if (results[i].textContent.match(regex)) {
			if (!matchedResult) {
				matchedResult = results[i]
			} else if (CodeRunnerDocsContext["isAutolookup"] == false) {
				matchedResult = false
				break
			}
		}
	}
	if (matchedResult) {
		setTimeout(function () {
			window.location.href = matchedResult.href
		}, CodeRunnerDocsContext["isAutolookup"] ? 100 : 700)
	}
})
