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
	// Table of contents
	var toc = function (elements, symbolKind) {
		for (var e of elements) {
			var title = e.textContent.trimLeft();
			if (symbolKind == "class" && title.startsWith("class ")) {
				title = title.substr(6);
			} else if (symbolKind == "method" && title.startsWith("classmethod ")) {
				title = title.substr(12);
			}
			e.dataset.coderunnerTocTitle = title;
			if (symbolKind) {
				e.dataset.coderunnerTocSymbolKind = symbolKind;
			}
		}
	}
	toc(document.querySelectorAll("dl.function > dt"), "function");
	toc(document.querySelectorAll("dl.class > dt"), "class");
	toc(document.querySelectorAll("dl.method > dt, dl.classmethod > dt"), "method");
	toc(document.querySelectorAll("dl.attribute > dt"), "attribute");
	toc(document.querySelectorAll(".section > dl.data > dt"), "constant");
	toc(document.querySelectorAll("dl.exception > dt"), "class");
	for (var e of document.querySelectorAll("dl dl > dt[data-coderunner-toc-title]")) {
		e.dataset.coderunnerTocLevel = "+1";
	}
	
	var autoredirect_to_result = function (docname, anchor) {
		if (window.location.hash != '') {
			return;
		}
		window.location.replace(window.location + '#results');
		setTimeout(function () {
			window.location.href = docname + ".html" + anchor;
		}, 100);
	}
	if (typeof Scorer != "undefined") {
		var didHideHeader = false;
		Scorer.score = function (result) {
			if (didHideHeader === false) {
				var searchHeader = document.querySelector("#search-results h2:first-child");
				if (searchHeader) {
					searchHeader.style.display = "none";
					didHideHeader = true;
				}
			}
			var docname = result[0];
			var name = result[1];
			var anchor = result[2];
			var description = result[3];
			var score = result[4];
			
			var kind = false;
			
			if (description) {
				var searchLocation = 0;
				var sectionNumberString = false
				while (true) {
					var sectionNumberStart = description.indexOf(", in ", searchLocation);
					if (sectionNumberStart == -1) {
						break;
					}
					if (kind === false) {
						kind = description.substring(0, sectionNumberStart);
					}
					sectionNumberStart += 5;
					if (description.length <= sectionNumberStart) {
						continue;
					}
					var c = description.charCodeAt(sectionNumberStart);
					if (c < 48 || c > 57) {
						searchLocation = sectionNumberStart;
						continue;
					}
					var sectionNumberEnd = description.indexOf(". ", sectionNumberStart);
					if (sectionNumberEnd != -1) {
						sectionNumberString = description.substr(sectionNumberStart, sectionNumberEnd-sectionNumberStart);
					}
					break;
				}
				if (!sectionNumberString) {
					sectionNumberString = sectionNumber(docname)
				}
				if (sectionNumberString) {
					var sectionScore = 0;
					var sectionNumbers = sectionNumberString.split(".");
					for (var i = 0; i < sectionNumbers.length; i++) {
						var number = parseFloat(sectionNumbers[i]);
						sectionScore += number/Math.pow(100, i);
					}
					score += 1000-2*sectionScore;
				}
			} else {
				score -= 1000;
			}
			
			var query = CodeRunnerDocsContext["query"];
			if (query) {
				if (query === name) {
					score += 10000;
				} else if (query.toUpperCase() === name.toUpperCase()) {
					score += 8000;
				} else if (name.startsWith(query) || name.endsWith(query)) {
					score += 4000;
					if (name.startsWith(query+".") || name.endsWith("."+query)) {
						score += 1000;
					}
				}
			}

			if (docname == "library/functions") {
				var builtins = ["abs","all","any","bin","bool","callable","chr","classmethod","compile","complex","delattr","dir","divmod","enumerate","eval","exec","filter","float","getattr","globals","hasattr","hash","help","id","input","int","isinstance","issubclass","iter","len","locals","map","max","min","next","object","oct","open","ord","print","property","repr","reversed","round","setattr","slice","sorted","staticmethod","sum","super","type","vars","zip","__import__","basestring","cmp","execfile","long","raw_input","reduce","reload","unichr","xrange"];
				if (builtins.indexOf(query) != -1) {
					autoredirect_to_result(docname, '#'+query);
				} else if (query == "range" && window.location.href.indexOf("/2/search") != -1) {
					autoredirect_to_result(docname, "#range")
				}
				score += 6000;
			} else if (docname == "library/stdtypes") {
				if (query == "dict" || query == "dicts") {
					autoredirect_to_result(docname, '#mapping-types-dict')
				} else if (query == "list" || query == "lists") {
					autoredirect_to_result(docname, '#lists')
				} else if (query == "range" || query == "ranges") {
					autoredirect_to_result(docname, '#ranges')
				} else if (query == "str" && name == "4. Built-in Types") {
					autoredirect_to_result(docname, '#text-sequence-type-str')
				} else if (query == "tuple" || query == "tuples") {
					autoredirect_to_result(docname, '#tuples')
				}
				score += 2000;
			}
			
			if (docname == "reference/simple_stmts" && ["assert","pass","del","return","yield","raise","break","continue","import","global","nonlocal","exec","print"].indexOf(query) != -1) {
				score += 2000;
				autoredirect_to_result(docname, '#'+query);
			} else if (docname == "reference/compound_stmts" && ["if","while","for","try","with","def","class"].indexOf(query) != -1) {
				score += 2000;
				autoredirect_to_result(docname, '#'+query);
			}
			
			var codeCompletion = CodeRunnerDocsContext["codeCompletionObject"];
			if (codeCompletion) {
				var full_name = codeCompletion["full_name"];
				if (full_name && (full_name === name || (full_name.startsWith("builtins.") && full_name.substr("builtins.".length) === name))) {
					var lookup_kind = codeCompletion["kind"];
					if ((kind == "Python function" && lookup_kind == "function") ||
						(kind == "Python method" && lookup_kind == "method") ||
						(kind == "Python module" && lookup_kind == "module") ||
						(kind == "Python exception" && lookup_kind == "class") ||
						(kind == "Python class" && lookup_kind == "class")
					) {
						autoredirect_to_result(docname, anchor)
					}
				}
			}
			
			if (docname == "library/2to3") {
				score -= 20000;
			}
			return score;
		}
	}
	var targetNode = document.getElementById('search-results');
	if (targetNode) {
		var observer;
		var callback = function(mutationsList) {
			for (var mutation of mutationsList) {
				if (targetNode) {
					for (var addedNode of mutation.addedNodes) {
						if (addedNode.nodeName == "P") {
							targetNode = null;
							observer.disconnect();
							observer.observe(addedNode, { childList: true });
							return;
						}
					}
				} else {
					if (mutation.target.textContent.indexOf("Your search did not match any documents.") != -1) {
						var sibling = mutation.target.previousElementSibling;
						if (sibling.nodeName == "H2") {
							sibling.innerHTML = "No Results";
						}
					}
				}
			}
		};
		observer = new MutationObserver(callback);
		observer.observe(targetNode, { childList: true });
	}
});

function sectionNumber(docname) {
	var sections = {"library/index":"1","library/intro":"2","library/functions":"3","library/constants":"4","library/stdtypes":"5","library/exceptions":"6","library/text":"7","library/string":"8","library/re":"9","library/difflib":"10","library/textwrap":"11","library/unicodedata":"12","library/stringprep":"13","library/readline":"14","library/rlcompleter":"15","library/binary":"16","library/struct":"17","library/codecs":"18","library/datatypes":"19","library/datetime":"20","library/calendar":"21","library/collections":"22","library/collections.abc":"23","library/heapq":"24","library/bisect":"25","library/array":"26","library/weakref":"27","library/types":"28","library/copy":"29","library/pprint":"30","library/reprlib":"31","library/enum":"32","library/numeric":"33","library/numbers":"34","library/math":"35","library/cmath":"36","library/decimal":"37","library/fractions":"38","library/random":"39","library/statistics":"40","library/functional":"41","library/itertools":"42","library/functools":"43","library/operator":"44","library/filesys":"45","library/pathlib":"46","library/os.path":"47","library/fileinput":"48","library/stat":"49","library/filecmp":"50","library/tempfile":"51","library/glob":"52","library/fnmatch":"53","library/linecache":"54","library/shutil":"55","library/macpath":"56","library/persistence":"57","library/pickle":"58","library/copyreg":"59","library/shelve":"60","library/marshal":"61","library/dbm":"62","library/sqlite3":"63","library/archiving":"64","library/zlib":"65","library/gzip":"66","library/bz2":"67","library/lzma":"68","library/zipfile":"69","library/tarfile":"70","library/fileformats":"71","library/csv":"72","library/configparser":"73","library/netrc":"74","library/xdrlib":"75","library/plistlib":"76","library/crypto":"77","library/hashlib":"78","library/hmac":"79","library/secrets":"80","library/allos":"81","library/os":"82","library/io":"83","library/time":"84","library/argparse":"85","library/getopt":"86","library/logging":"87","library/logging.config":"88","library/logging.handlers":"89","library/getpass":"90","library/curses":"91","library/curses.ascii":"92","library/curses.panel":"93","library/platform":"94","library/errno":"95","library/ctypes":"96","library/concurrency":"97","library/threading":"98","library/multiprocessing":"99","library/concurrent":"100","library/concurrent.futures":"101","library/subprocess":"102","library/sched":"103","library/queue":"104","library/_thread":"105","library/_dummy_thread":"106","library/dummy_threading":"107","library/contextvars":"108","library/ipc":"109","library/asyncio":"110","library/asyncio-task":"111","library/asyncio-stream":"112","library/asyncio-sync":"113","library/asyncio-subprocess":"114","library/asyncio-queue":"115","library/asyncio-exceptions":"116","library/asyncio-eventloop":"117","library/asyncio-future":"118","library/asyncio-protocol":"119","library/asyncio-policy":"120","library/asyncio-platforms":"121","library/asyncio-api-index":"122","library/asyncio-llapi-index":"123","library/asyncio-dev":"124","library/socket":"125","library/ssl":"126","library/select":"127","library/selectors":"128","library/asyncore":"129","library/asynchat":"130","library/signal":"131","library/mmap":"132","library/netdata":"133","library/email":"134","library/email.message":"135","library/email.parser":"136","library/email.generator":"137","library/email.policy":"138","library/email.errors":"139","library/email.headerregistry":"140","library/email.contentmanager":"141","library/email.examples":"142","library/email.compat32-message":"143","library/email.mime":"144","library/email.header":"145","library/email.charset":"146","library/email.encoders":"147","library/email.util":"148","library/email.iterators":"149","library/json":"150","library/mailcap":"151","library/mailbox":"152","library/mimetypes":"153","library/base64":"154","library/binhex":"155","library/binascii":"156","library/quopri":"157","library/uu":"158","library/markup":"159","library/html":"160","library/html.parser":"161","library/html.entities":"162","library/xml":"163","library/xml.etree.elementtree":"164","library/xml.dom":"165","library/xml.dom.minidom":"166","library/xml.dom.pulldom":"167","library/xml.sax":"168","library/xml.sax.handler":"169","library/xml.sax.utils":"170","library/xml.sax.reader":"171","library/pyexpat":"172","library/internet":"173","library/webbrowser":"174","library/cgi":"175","library/cgitb":"176","library/wsgiref":"177","library/urllib":"178","library/urllib.request":"179","library/urllib.parse":"180","library/urllib.error":"181","library/urllib.robotparser":"182","library/http":"183","library/http.client":"184","library/ftplib":"185","library/poplib":"186","library/imaplib":"187","library/nntplib":"188","library/smtplib":"189","library/smtpd":"190","library/telnetlib":"191","library/uuid":"192","library/socketserver":"193","library/http.server":"194","library/http.cookies":"195","library/http.cookiejar":"196","library/xmlrpc":"197","library/xmlrpc.client":"198","library/xmlrpc.server":"199","library/ipaddress":"200","library/mm":"201","library/audioop":"202","library/aifc":"203","library/sunau":"204","library/wave":"205","library/chunk":"206","library/colorsys":"207","library/imghdr":"208","library/sndhdr":"209","library/ossaudiodev":"210","library/i18n":"211","library/gettext":"212","library/locale":"213","library/frameworks":"214","library/turtle":"215","library/cmd":"216","library/shlex":"217","library/tk":"218","library/tkinter":"219","library/tkinter.ttk":"220","library/tkinter.tix":"221","library/tkinter.scrolledtext":"222","library/idle":"223","library/othergui":"224","library/development":"225","library/typing":"226","library/pydoc":"227","library/doctest":"228","library/unittest":"229","library/unittest.mock":"230","library/unittest.mock-examples":"231","library/2to3":"232","library/test":"233","library/debug":"234","library/bdb":"235","library/faulthandler":"236","library/pdb":"237","library/profile":"238","library/timeit":"239","library/trace":"240","library/tracemalloc":"241","library/distribution":"242","library/distutils":"243","library/ensurepip":"244","library/venv":"245","library/zipapp":"246","library/python":"247","library/sys":"248","library/sysconfig":"249","library/builtins":"250","library/__main__":"251","library/warnings":"252","library/dataclasses":"253","library/contextlib":"254","library/abc":"255","library/atexit":"256","library/traceback":"257","library/__future__":"258","library/gc":"259","library/inspect":"260","library/site":"261","library/custominterp":"262","library/code":"263","library/codeop":"264","library/modules":"265","library/zipimport":"266","library/pkgutil":"267","library/modulefinder":"268","library/runpy":"269","library/importlib":"270","library/language":"271","library/parser":"272","library/ast":"273","library/symtable":"274","library/symbol":"275","library/token":"276","library/keyword":"277","library/tokenize":"278","library/tabnanny":"279","library/pyclbr":"280","library/py_compile":"281","library/compileall":"282","library/dis":"283","library/pickletools":"284","library/misc":"285","library/formatter":"286","library/windows":"287","library/msilib":"288","library/msvcrt":"289","library/winreg":"290","library/winsound":"291","library/unix":"292","library/posix":"293","library/pwd":"294","library/spwd":"295","library/grp":"296","library/crypt":"297","library/termios":"298","library/tty":"299","library/pty":"300","library/fcntl":"301","library/pipes":"302","library/resource":"303","library/nis":"304","library/syslog":"305","library/superseded":"306","library/optparse":"307","library/imp":"308","library/undoc":"309"};
	return sections[docname]
}
