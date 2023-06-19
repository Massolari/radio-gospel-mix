import { Elm } from "./Main.elm";

const app = Elm.Main.init({
  node: document.getElementById("app"),
});

app.ports.copyToClipboard.subscribe((song: string) => {
  navigator.clipboard.writeText(song).then(() => {
    app.ports.copiedToClipboard.send(song);
  });
});

app.ports.playPause.subscribe(() => {
  const audio = document.querySelector<HTMLAudioElement>("audio");

  if (!audio) {
    console.error("No audio element found");
    return;
  }

  if (audio.paused) {
    audio.play();
    return;
  }

  audio.pause();
});
