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
