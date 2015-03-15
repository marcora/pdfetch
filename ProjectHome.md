**pdfetch** is a small web app that automagically fetches the PDF reprint of a [PubMed](http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed) article given its PMID.
If **pdfetch** cannot find a local copy of the reprint, then it downloads the reprint from the publisher's website to the local repository (of course only if the reprint is free or if you have authorized access to it, e.g., via your university library).

**pdfetch** can also be used for the creation of a shared local repository of PDF reprints  designed for small trusted groups, e.g. science labs, by having every member of the group point to the same local server running **pdfetch**.

If you use the "ferret" branch version of **pdfetch**, PDF reprints in the local repository can be easily searched using any web browser.

**pdfetch** is best used from PubMed using a **bookmarklet** (for any modern web browser) or a **greasemonkey script** (for Firefox only). Both assume that the pdfetch server is listening on `localhost:3301` and that Javascript is enabled in your web browser.

To install the bookmarklet just drag the link in the list to your right onto your Links/Bookmarks toolbar/menu. To use the bookmarklet, just click it when using PubMed (of course the pdfetch server needs to be running too!).

To install the greasemonkey script just make sure you are using Firefox + Greasemonkey and click on [this link](http://pdfetch.googlecode.com/svn/trunk/pubmed2pdfetch.user.js). It adds a 'Fetch' link to the article display page in PubMed for easy access to **pdfetch**.

**pdfetch** requires [Camping](http://rubyforge.org/projects/camping/) and [Mechanize](http://rubyforge.org/projects/mechanize/).

To install **pdfetch** follow these easy steps:

  1. install [Ruby](http://www.ruby-lang.org/en/) +  [RubyGems](http://www.ruby-lang.org/en/libraries/#installing-rubygems)
  1. install camping, mechanize, and mongrel by executing the following command `gem install camping mechanize mongrel --include-dependencies`
  1. save [pdfetch.rb](http://pdfetch.googlecode.com/svn/trunk/pdfetch.rb) in the directory where you want the PDF reprints to reside.
  1. launch the pdfetch server by executing the following command `camping pdfetch.rb` or (for better security) `camping -h 127.0.0.1 pdfetch.rb`. You can change the port that the pdfetch server listens to (default is 3301) by executing the following command `camping -p <port number> pdfetch.rb`. If you have any problem, add `-s mongrel` to any of the above commands.
  1. you are ready to go!!! You can fetch the PDF reprint of a PubMed article with PMID '123456' by going to http://localhost:3301/fetch/123456 in your web browser, or by using the bookmarklet/greasemonkey script directly from PubMed.




























