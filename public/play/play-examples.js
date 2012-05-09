/**
 * The RDFa Play example files.
 *
 * @author Manu Sporny <msporny@digitalbazaar.com>
 */
(function($) {
  window.play.examples = window.play.examples || {};
  var examples = window.play.examples;

  examples['person'] = 
  '<div vocab="http://schema.org/" typeof="Person">\n'+
  '  <a property="image" href="http://manu.sporny.org/images/manu.png">\n' +
  '    <span property="name">Manu Sporny</span></a>, \n' +
  '  <span property="jobTitle">Founder/CEO</span>\n' +
  '  <div>\n' +
  '    Phone: <span property="telephone">(540) 961-4469</span>\n' +
  '  </div>\n' +
  '  <div>\n' +
  '    E-mail: <a property="email" href="mailto:msporny@digitalbazaar.com">msporny@digitalbazaar.com</a>\n' +
  '  </div>\n' +
  '  <div>\n' +
  '    Links: <a property="url" href="http://manu.sporny.org/">Manu\'s homepage</a>\n' +
  '  </div>\n' +
  '</div>';

  examples['social-network'] = 
  '<div vocab="http://xmlns.com/foaf/0.1/">\n' +
  '  <div resource="#manu" typeof="Person">\n'+
  '    <span property="name">Manu Sporny</span> knows\n'+
  '    <a property="knows" href="#alex">Alex</a> and\n'+
  '    <a property="knows" href="#brian">Brian</a>.\n'+
  '  </div>\n'+
  '  <div resource="#alex" typeof="Person">\n'+
  '    <span property="name">Alex Milowski</span> wrote the RDFa processor for this page.\n'+
  '  </div>\n'+
  '  <div resource="#brian" typeof="Person">\n'+
  '    <span property="name">Brian Sletten</span> wrote the syntax highlighting for the raw data.\n'+
  '  </div>\n'+
  '</div>';

  examples['event'] = 
  '<div vocab="http://schema.org/" typeof="Event">\n'+
  '  <a property="url" href="nba-miami-philidelphia-game3.html">\n'+
  '  NBA Eastern Conference First Round Playoff Tickets:\n'+
  '  <span itemprop="name">Miami Heat at Philadelphia 76ers - Game 3 (Home Game 1)</span>\n'+
  '  </a>\n'+
  '\n'+
  '  <span property="startDate" content="2011-04-21T20:00">\n'+
  '    Thu, 04/21/11\n'+
  '    8:00 p.m.\n'+
  '  </span>\n'+
  '\n'+
  '  <div property="location" typeof="Place">\n'+
  '    <a property="url" href="wells-fargo-center.html">\n'+
  '    Wells Fargo Center\n'+
  '    </a>\n'+
  '    <div property="address" typeof="PostalAddress">\n'+
  '      <span property="addressLocality">Philadelphia</span>,\n'+
  '      <span property="addressRegion">PA</span>\n'+
  '    </div>\n'+
  '  </div>\n'+
  '\n'+
  '  <div property="offers" typeof="AggregateOffer">\n'+
  '    Priced from: <span property="lowPrice">$35</span>\n'+
  '    <span property="offerCount">1,938</span> tickets left\n'+
  '  </div>\n'+
  '</div>';

  examples['place'] = 
  '<div vocab="http://schema.org/" resource="#bbg" typeof="LocalBusiness">\n'+
  '  <h1 property="name">Beachwalk Beachwear &amp; Giftware</h1>\n'+
  '  <span property="description"> A superb collection of fine gifts and clothing\n'+
  '  to accent your stay in Mexico Beach.</span>\n'+
  '  <div property="address" resource="#bbg-address" typeof="PostalAddress">\n'+
  '    <span property="streetAddress">3102 Highway 98</span>\n'+
  '    <span property="addressLocality">Mexico Beach</span>,\n'+
  '    <span property="addressRegion">FL</span>\n'+
  '  </div>\n'+
  '  Phone: <span property="telephone">850-648-4200</span>\n'+
  '</div>';
  
  examples['product'] =   
  '<div prefix="\n'+
  '  rdf: http://www.w3.org/1999/02/22-rdf-syntax-ns#\n'+
  '  foaf: http://xmlns.com/foaf/0.1/\n'+
  '  gr: http://purl.org/goodrelations/v1#\n'+
  '  xsd: http://www.w3.org/2001/XMLSchema#"\n'+
  '  typeof="gr:Offering">\n'+
  '  <div>\n'+
  '    <h1 property="gr:name">Canon Rebel T2i (EOS 550D)</h1>\n'+
  '    <div rel="foaf:depiction">\n'+
  '      <img style="float:left; width:20%" src="http://shop.usa.canon.com/wcsstore/eStore/images/t2ikit_1_l.jpg" />\n'+
  '    </div>\n'+
  '    <p property="gr:description">\n'+
  '      The Canon Rebel T2i (EOS 550D) is Cannon\'s top-of-the-line consumer digital SLR camera.\n'+
  '	  It can shoot up to 18 megapixel resolution photos and features an ISO range of 100-6400.\n'+
  '    </p>\n'+
  '    <link rel="gr:hasBusinessFunction" href="http://purl.org/goodrelations/v1#Sell" />\n'+
  '    <meta property="gr:hasEAN_UCC-13" content="013803123784" />\n'+
  '    Sale price:\n'+
  '    <span property="gr:hasPriceSpecification" typeof="gr:UnitPriceSpecification">\n'+
  '      <span property="gr:hasCurrency" content="USD">$</span>\n'+
  '      <span property="gr:hasCurrencyValue" datatype="xsd:float">899</span>\n'+
  '    </span>\n'+
  '    <link rel="gr:acceptedPaymentMethods" href="http://purl.org/goodrelations/v1#PayPal" />\n'+
  '    <link rel="gr:acceptedPaymentMethods" href="http://purl.org/goodrelations/v1#MasterCard" />\n'+
  '    [<a rel="foaf:page" href="http://shop.usa.canon.com/">more...</a>]\n'+
  '  </div>\n'+
  '</div>';
})(jQuery);
