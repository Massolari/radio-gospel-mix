import { Elm } from "./Main.elm";

const radio = new URL(window.location.href).searchParams.get("radio");

console.log({ radio });
const app = Elm.Main.init({
  node: document.getElementById("app"),
  flags: {
    radio,
  },
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

app.ports.changeUrlQuery.subscribe((query: string) => {
  const url = new URL(window.location.href);
  url.searchParams.set("radio", query);
  history.replaceState({}, "", url.toString());
});
