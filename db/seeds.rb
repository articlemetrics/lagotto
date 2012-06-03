# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

# Load default groups
social_bookmarks = Group.find_or_create_by_name(:name => "Social Bookmarks")
citations = Group.find_or_create_by_name(:name => "Citations")
blog_entries = Group.find_or_create_by_name(:name => "Blog Entries")
statistics = Group.find_or_create_by_name(:name => "Statistics")
testing = Group.find_or_create_by_name(:name => "Testing")

# Load default sources
citeulike = Citeulike.find_or_create_by_name(  
	:name => "citeulike", 
	:display_name => "CiteULike", 
	:active => true, 
	:workers => 1,
	:group_id => social_bookmarks.id,
	:url => "http://www.citeulike.org/api/posts/for/doi/%{doi}" )
  
pubmed = PubMed.find_or_create_by_name(  
  :name => "pubmed", 
  :display_name => "PubMed", 
  :active => true, 
  :workers => 1,
  :group_id => citations.id,
  :url => "http://www.pubmedcentral.nih.gov/utils/entrez2pmcciting.cgi?view=xml&id=%{pub_med}")
  
wikipedia = Wikipedia.find_or_create_by_name(  
  :name => "wikipedia", 
  :display_name => "Wikipedia", 
  :active => true, 
  :workers => 3,
  :group_id => citations.id,
  :url => "http://%{host}/w/api.php?action=query&list=search&format=json&srsearch=%{doi}&srnamespace=%{namespace}&srwhat=text&srinfo=totalhits&srprop=timestamp&sroffset=%{offset}&srlimit=%{limit}&maxlag=%{maxlag}")

  # Load sample articles
  Article.find_or_create_by_doi(
    :doi => "10.1371/journal.pone.0008776",
    :title => "The \"Island Rule\" and Deep-Sea Gastropods: Re-Examining the Evidence",
    :published_on => "2010-01-19")
  
  Article.find_or_create_by_doi(
    :doi => "10.1371/journal.pcbi.1000204",
    :title => "Defrosting the Digital Library: Bibliographic Tools for the Next Generation Web",
    :published_on => "2008-10-31")
    
  Article.find_or_create_by_doi(
    :doi => "10.1371/journal.pone.0018657",
    :title => "Who Shares? Who Doesn't? Factors Associated with Openly Archiving Raw Research Data",
    :published_on => "2011-07-13")
    
    Article.find_or_create_by_doi(
      :doi => "10.1371/journal.pcbi.0010057",
      :title => "Ten Simple Rules for Getting Published",
      :published_on => "2005-10-28")
      
    Article.find_or_create_by_doi(
      :doi => "10.1371/journal.pone.0000443",
      :title => "Order in Spontaneous Behavior",
      :published_on => "2007-05-16")
      
    Article.find_or_create_by_doi(
      :doi => "10.1371/journal.pbio.1000242",
      :title => "Article-Level Metrics and the Evolution of Scientific Impact",
      :published_on => "2009-11-17")
      
    Article.find_or_create_by_doi(
      :doi => "10.1371/journal.pone.0035869",
      :title => "Research Blogs and the Discussion of Scholarly Information",
      :published_on => "2012-05-11")
          
    Article.find_or_create_by_doi(
      :doi => "10.1371/journal.pmed.0020124",
      :title => "Why Most Published Research Findings Are False",
      :published_on => "2005-08-30")
      
    Article.find_or_create_by_doi(
      :doi => "10.1371/journal.pone.0036240",
      :title => "How Academic Biologists and Physicists View Science Outreach",
      :published_on => "2012-05-09")
      
    Article.find_or_create_by_doi(
      :doi => "10.1371/journal.pone.0000000",
      :title => "PLoS Journals Sandbox: A Place to Learn and Play",
      :published_on => "2006-12-20")
	  
	  Article.find_or_create_by_doi(
	    :doi => "10.1371/journal.pmed.0020146",
	    :title => "How Prevalent Is Schizophrenia?",
	    :published_on => "2005-05-31")
		
	  Article.find_or_create_by_doi(
	    :doi => "10.1371/journal.pbio.0030137",
	    :title => "Perception Space-The Final Frontier",
	    :published_on => "2005-04-12")
      
	  Article.find_or_create_by_doi(
	    :doi => "10.1371/journal.pcbi.1002445",
	    :title => "Circular Permutation in Proteins",
	    :published_on => "2012-03-29")
      
	  Article.find_or_create_by_doi(
	    :doi => "10.1371/journal.pone.0036790",
	    :title => "New Dromaeosaurids (Dinosauria: Theropoda) from the Lower Cretaceous of Utah, and the Evolution of the Dromaeosaurid Tail",
	    :published_on => "2012-05-15")
      
	  Article.find_or_create_by_doi(
	    :doi => "10.1371/journal.pbio.0060188",
	    :title => "Going, Going, Gone: Is Animal Migration Disappearing",
	    :published_on => "2008-07-29")
        
	  Article.find_or_create_by_doi(
	    :doi => "10.1371/journal.pone.0020381",
	    :title => "Dinosaur Peptides Suggest Mechanisms of Protein Survival",
	    :published_on => "2011-06-08")
        
	  Article.find_or_create_by_doi(
	    :doi => "10.1371/journal.pone.0001636",
	    :title => "Measuring the Meltdown: Drivers of Global Amphibian Extinction and Decline",
	    :published_on => "2008-02-20")
      
	  Article.find_or_create_by_doi(
	    :doi => "10.1371/journal.pone.0006872",
	    :title => "Persistent Exposure to Mycoplasma Induces Malignant Transformation of Human Prostate Cells",
	    :published_on => "2009-09-01")
      
	  Article.find_or_create_by_doi(
	    :doi => "10.1371/journal.pcbi.0020131",
	    :title => "Sampling Realistic Protein Conformations Using Local Structural Bias",
	    :published_on => "2006-09-22")
      
	  Article.find_or_create_by_doi(
	    :doi => "10.1371/journal.pbio.0040015",
	    :title => "Thriving Community of Pathogenic Plant Viruses Found in the Human Gut",
	    :published_on => "2005-12-20")