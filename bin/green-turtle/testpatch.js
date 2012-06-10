var baseURI = "http://rdfa.info/play/";
document.baseURI = baseURI;
var hasFeature = document.implementation.hasFeature;
document.implementation.hasFeature = function (feature, version) {
    return true;
};
window.play = {};
