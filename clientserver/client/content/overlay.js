var pdfetch = {

    on_load: function() {
        // initialization code
        this.initialized = true;
        this.strings = document.getElementById("pdfetch-strings");
        document.getElementById("contentAreaContextMenu")
        .addEventListener("popupshowing", function(e) { this.on_show_contextmenu(); }, false);
    },

    url_for: function() {
        // url helper
        const BASE_URL = "http://localhost:4567";
        arguments.join = Array.prototype.join;
        return BASE_URL + '/' + arguments.join('/');
    },

    on_show_contextmenu: function() {
        // show or hide the menuitem based on what the context menu is on
        document.getElementById("pdfetch-contextmenu").hidden = gContextMenu.onImage;
    },

    get_pdf: function(pdf_url) {
        try {
            var ioservice = Components.classes["@mozilla.org/network/io-service;1"]
            .getService(Components.interfaces.nsIIOService);
            var channel = ioservice.newChannel(pdf_url, null, null);
            var inputstream = channel.open();
            if (channel instanceof Components.interfaces.nsIHttpChannel && channel.responseStatus == 200) {
                var binaryinputstream = Components.classes["@mozilla.org/binaryinputstream;1"]
                .createInstance(Components.interfaces.nsIBinaryInputStream);
                binaryinputstream.setInputStream(inputstream);
                var size;
                var pdf = '';
                var is_pdf = false;
                while(size = binaryinputstream.available()) {
                    pdf += binaryinputstream.readBytes(size);
                    // check if pdf
                    if ( !is_pdf && pdf.match(/^%PDF-1\.\d{1}/) ) { is_pdf = true }
                    if ( !is_pdf ) { pdf = ''; break }
                }
                return pdf;
            } else { return '' }
        } catch (e) { return '' }
    },

    post_pdf: function(pdf, url) {
        // check if pdf
        if (!pdf.match(/^%PDF-1\.\d{1}/)) {
            return '';
        }
        // check size of pdf
        var max_filesize = 10*1048576; // 10 megabytes max filesize
        if (pdf.length > max_filesize) {
            return '';
        }
        try {
            var req = new XMLHttpRequest();
            req.open('POST', url, false); // synchronous request
            req.setRequestHeader("Content-Type", "application/pdf");
            req.setRequestHeader("Content-Length", pdf.size);
            req.sendAsBinary(pdf);
            if (req.status == 200) {
                //var json = Components.classes["@mozilla.org/dom/json;1"]
                //.createInstance(Components.interfaces.nsIJSON);
                var reprint_filename = req.responseText; //json.decode(req.responseText);
                return reprint_filename;
            } else { return '' }
        } catch (e) { return '' }
    },

    get_pdf_urls: function(url, id) {
        if (id) {
            var url = this.url_for('pdf_urls?url='+escape(url)+'&id='+escape(id));
        } else {
            var url = this.url_for('pdf_urls?url='+escape(url));
        }
        try {
            var req = new XMLHttpRequest();
            req.open('get', url, false); // synchronous request
            req.send(null);
            if (req.status == 200) {
                var json = Components.classes["@mozilla.org/dom/json;1"]
                .createInstance(Components.interfaces.nsIJSON);
                var pdf_urls = json.decode(req.responseText);
                if (pdf_urls instanceof Array) { return pdf_urls } else { return [] }
            } else { return [] }
        } catch (e) { return [] }
    },

    on_menuitem_command: function() {
        var url = content.document.URL; // getBrowser().selectedBrowser.webNavigation.currentURI.spec
        var pdf = '';
        if (content.document.contentType == 'application/pdf') {
            pdf = this.get_pdf(url);
            if ( pdf ) {
                var reprint_filename = this.post_pdf(pdf, this.url_for('reprints'));
                if ( reprint_filename ) {
                    content.document.location.href = this.url_for('reprints', reprint_filename);
                } else {
                    alert("server error");
                }
            } else {
                alert("pdf not found");
            }
        } else {
            var id; // TODO: get id (pmid or doi) from document
            var pdf_urls = this.get_pdf_urls(url);
            alert(pdf_urls);
            for (var i = 0, pdf_url; pdf_url = pdf_urls[i]; i++) {
                pdf = this.get_pdf(pdf_url);
                if ( pdf ) { break }
            }
            if ( pdf ) {
                var reprint_filename = this.post_pdf(pdf, this.url_for('reprints'));
                if ( reprint_filename ) {
                    content.document.location.href = this.url_for('reprints', reprint_filename);
                } else {
                    alert("server error");
                }
            } else {
                alert("pdf not found");
            }
        }
    },

    on_toolbarbutton_command: function() {
        pdfetch.on_menuitem_command();
    },

};

window.addEventListener("load", function(e) { pdfetch.on_load(); }, false);
