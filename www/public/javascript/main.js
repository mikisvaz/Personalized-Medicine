function show_hide(){
  var target = $("#" + $(this).attr('ref'));
  target.toggle();
  return false;
}
