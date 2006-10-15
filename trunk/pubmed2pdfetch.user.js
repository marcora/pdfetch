// pubmed2pdfetch
// version 0.1
// 2006-10-15
// Copyright (c) 2006, Edoardo "Dado" Marcora, Ph.D. <http://marcora.caltech.edu/>
// Released under the MIT license <http://www.opensource.org/licenses/mit-license.php>
// --------------------------------------------------------------------
//
// This is a Greasemonkey user script.  To install it, you need
// Greasemonkey 0.6.4 or later: http://greasemonkey.mozdev.org/
// and Firefox 1.5 : http://www.mozilla.com/
// Then restart Firefox and revisit this script.
// Under Tools, there will be a new menu item to "Install User Script".
// Accept the default configuration and install.
//
// To uninstall, go to Tools/Manage User Scripts,
// select "pubmed2connotea", and click Uninstall.
//
// --------------------------------------------------------------------

// ==UserScript==
// @name          pubmed2connotea
// @namespace     http://www.integragen.com
// @description   append a shortcut link used to add an entry in http://www.connotea.org or http://www.citeulike.org/ when browsing NCBI pubmed
// @include       http://www.ncbi.nlm.nih.gov/entrez/*
// ==/UserScript==




function gm_xpath(expression,contextNode){
    return document.evaluate(expression,contextNode,null,XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE,null);
}

function getURLParameter(url,parameter){
    if(url==null) return null;
    var a= url.indexOf("?");
    if(a==-1) return null;
    if(url.indexOf(parameter+"=")==-1) return null;
    var params= url.substring(a+1).split("&");
    var i=0;
    for(i=0;i<params.length;i++)
        {
            b= params[i].indexOf("=");
            if(b==-1) continue;
            var key = params[i].substring(0,b);
            if(key!=parameter) continue;
            return params[i].substring(b+1);
        }
    return null;
}

function escapeURL(url){
    var s="";
    var i=0;

    for(i=0;i< url.length;++i)
        {
            var c=url.charAt(i)
                switch( c )
                    {
                    case ':': s+= '%3A'; break;
                    case '/': s+= '%2F'; break;
                    case '?': s+= '%3F'; break;
                    case '=': s+= '%3D'; break;
                    case '&': s+= '%26'; break;
                    default : s+= c; break;
                    }
        }
    return s;
}


function insertPubmed2Pdfetch(){

    var pmid = '';
    var re = /PMID:\s+(\d+)\s+/;
    var html = document.body.innerHTML;
    var pos = html.search(re);
    
    if (pos>=0){

        pmid =re.exec(html)[1]; 
	
        var a = document.createElement("a");
        a.setAttribute("title","Download reprint of this article using PDFetch");
        a.setAttribute("href","http://localhost:8888/fetch/"+pmid);
        a.setAttribute("class","dblinks");
    
        var anchor = document.createTextNode("Download");
    
        a.appendChild(anchor);

        var e = document.evaluate(
                                  "//span[@class='linkbar']",
                                  document.body,
                                  null,
                                  XPathResult.FIRST_ORDERED_NODE_TYPE,
                                  null).singleNodeValue;

        e.appendChild(a);
    }
}

window.addEventListener("load", insertPubmed2Pdfetch, false);
