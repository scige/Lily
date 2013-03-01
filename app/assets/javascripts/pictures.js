$(function(){
  $("#reset-button").click(function(){
    $("#url").val("");
    //$("#title").val("");
  });

  $("#url").click(function(){
    $("#url").val("");
    //$("#title").val("");
  });

  $("td img").mouseover(function(e){
    $(e.target).attr("width", "128");
  });

  $("td img").mouseout(function(e){
    $(e.target).attr("width", "32");
  });
});

