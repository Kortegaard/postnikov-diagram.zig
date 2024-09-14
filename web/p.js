
var send_labels = Module.cwrap('updateLabelCollection', '', ['string']);
var z_setShowPlabicGraph = Module.cwrap('setShowPlabicGraph', '', ['bool']);
var z_setShowQuiver = Module.cwrap('setShowQuiver', '', ['bool']);
var z_setShowStrands = Module.cwrap('setShowStrands', '', ['bool']);
var z_updateFromStandardSeed = Module.cwrap('updateFromStandardSeed', '', ['number', 'number']);
