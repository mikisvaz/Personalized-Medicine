function update_genecard(gene){
    $.ajax({
      url : genecard_href,
      data : {gene : gene},
      success : function(response){
        $('#genecard').html(response);
        $('#tabs').tabs();
    }})
    return false;
}

function expand_field(code){
  var link = $('a#' + code);
  var content = unescape(link.attr('value'));
  link.parent('div').html(content);
}

