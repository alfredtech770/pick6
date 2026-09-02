// winback-email — a three touch reconquest sequence for dead subscriptions.
//
// WHY A SEQUENCE AND NOT ONE EMAIL.
//
// The first version of this function sent one email per person, segmented by
// how they left. That is the right segmentation and it is kept below, but one
// email is the wrong shape for this audience. These people did not bounce off
// a landing page, they installed the app, created an account, entered a
// payment method and then stopped. A single send asks them to re-decide in one
// sitting, with one argument, on whichever day the cron happens to fire.
//
// Three touches split the argument into the three things that actually have to
// land, in the order they have to land in:
//
//   T1  THE RECORD          What the model actually did on the window that
//                           starts the day their access ended. Computed per
//                           recipient from `picks`. Wins and losses in the
//                           same number. This is the only touch that differs
//                           by segment, because the reason they left changes
//                           the first sentence and nothing after it.
//
//   T2  WHAT CHANGED        Not a claim, a count. The sports that carried a
//                           pick in the last fourteen days and the number of
//                           calls logged since they left, both read out of
//                           `picks` at send time. A trial that ended in June
//                           saw two leagues. The board is wider now, and the
//                           email proves it instead of asserting it.
//
//   T3  THE OFFER           The Apple win back offer, with its redemption
//                           link. Deliberately last: an offer sent first is a
//                           discount, an offer sent after two honest emails is
//                           a way to act on them. T3 REFUSES TO SEND unless
//                           WINBACK_OFFER_URL and WINBACK_OFFER_LABEL are both
//                           set, so it can never promise an offer that does
//                           not exist in App Store Connect.
//
// Spacing is enforced from `email_log`: T2 needs a delivered T1 at least
// T2_AFTER_DAYS old, T3 needs a delivered T2 at least T3_AFTER_DAYS old. A
// person who never got T1 can never receive T2, so a failed send stalls that
// person's sequence rather than skipping a step.
//
// DOMAIN WARMING. pick1.live has never sent a single email, which means it has
// no sending reputation at all. Dropping 562 messages on day one is the
// fastest way to land the domain in spam permanently. DAILY_CAP bounds every
// run against what has already been sent TODAY across all touches, read back
// out of email_log, so an hourly cron cannot outrun it. Raise it gradually.
//
// SEND ORDER. T3, then T2, then T1. People already in the sequence finish it
// before the cap is spent starting new ones.
//
// COPY RULE, inherited and non negotiable.
// No performance promises, no returns, no implied outcomes, no "place a bet".
// Pick1 tracks picks, it does not take them. Every number in every email is
// computed here from production data, including the bad ones. A win back that
// lies is worth less than no win back, and the whole position of the product
// (and its Meta ads eligibility) rests on publishing the losses too.
//
// CONSENT. Marketing to lapsed customers, not a transactional notice. Honours
// email_preferences.newsletter, creates the preferences row before sending so
// the unsubscribe link always resolves, and carries both a visible unsubscribe
// link and RFC 8058 one click headers.
//
// POST body (all optional):
//   { dryRun: true }              resolve and preview, send nothing
//   { only: ["t1","t2","t3"] }    run just these touches
//   { limit: 50 }                 cap per touch (default 200)
//   { dailyCap: 30 }              cap across the whole day (default 30)
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_KEY = Deno.env.get("RESEND_API_KEY");
const EMAIL_FROM = Deno.env.get("EMAIL_FROM") ?? "Pick1 <hello@pick1.live>";
// Set these two once the win back offer exists in App Store Connect. Until
// then T3 refuses to run rather than describing an offer nobody can redeem.
const OFFER_URL = Deno.env.get("WINBACK_OFFER_URL");
const OFFER_LABEL_EN = Deno.env.get("WINBACK_OFFER_LABEL");

const APP_URL = "https://pick1.live";
const UNSUB_BASE = `${SUPABASE_URL}/functions/v1/email-unsubscribe`;

const T2_AFTER_DAYS = 4;
const T3_AFTER_DAYS = 5;
const DEFAULT_DAILY_CAP = 30;
// Resend's baseline is 2 requests a second. Staying well under it also makes
// the send look less like a blast to receiving mail servers.
const SEND_GAP_MS = 700;

type Seg = "payment" | "churned" | "trial";
type Touch = "t1" | "t2" | "t3";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------- copy

type Copy = {
  subject: string; preheader: string; badge: string;
  h1: string; h2: string; p1: string; p2: string; cta: string;
  panelLabel: string; unsub: string; greet: string;
};

// T1 differs by why they left. T2 and T3 are shared, because by then the
// argument is about the product and the offer, not about their exit.
const T1: Record<Seg, Record<string, Copy>> = {
  payment: {
    en: { greet: "Hi", subject: "Your Pick1 subscription stopped on a failed card",
      preheader: "It wasn't cancelled. The charge just didn't go through.",
      badge: "BILLING &middot; NOT A CANCELLATION", h1: "YOU DIDN'T", h2: "CANCEL.",
      p1: "Your Pick1 Pro subscription ended because a card charge failed, not because you chose to leave. Apple retried, the payment never cleared, and access lapsed.",
      p2: "Here is what the model called in the meantime, wins and losses in the same number. If that was a card you have since replaced, starting again takes one tap. Nothing was charged while you were away.",
      cta: "Restart Pick1 Pro", panelLabel: "SETTLED RECORD SINCE YOUR ACCESS ENDED", unsub: "Unsubscribe" },
    fr: { greet: "Salut", subject: "Ton abonnement Pick1 s'est arr&ecirc;t&eacute; sur un paiement refus&eacute;",
      preheader: "Ce n'était pas une résiliation. Le prélèvement n'est pas passé.",
      badge: "FACTURATION &middot; PAS UNE R&Eacute;SILIATION", h1: "TU N'AS RIEN", h2: "R&Eacute;SILI&Eacute;.",
      p1: "Ton abonnement Pick1 Pro s'est arrêté parce qu'un prélèvement a échoué, pas parce que tu as choisi de partir. Apple a réessayé, le paiement n'est jamais passé, et l'accès s'est interrompu.",
      p2: "Voilà ce que le modèle a annoncé entre temps, victoires et défaites dans le même chiffre. Si c'était une carte que tu as changée depuis, reprendre prend un geste. Rien ne t'a été facturé pendant ton absence.",
      cta: "Reprendre Pick1 Pro", panelLabel: "BILAN R&Eacute;EL DEPUIS LA FIN DE TON ACC&Egrave;S", unsub: "Se désinscrire" },
    es: { greet: "Hola", subject: "Tu suscripci&oacute;n a Pick1 se detuvo por un pago rechazado",
      preheader: "No fue una cancelación. El cobro no se procesó.",
      badge: "FACTURACI&Oacute;N &middot; NO ES UNA CANCELACI&Oacute;N", h1: "T&Uacute; NO", h2: "CANCELASTE.",
      p1: "Tu suscripción Pick1 Pro terminó porque falló un cobro, no porque decidieras irte. Apple lo reintentó, el pago nunca se completó y el acceso se interrumpió.",
      p2: "Esto es lo que el modelo pronosticó mientras tanto, aciertos y fallos en la misma cifra. Si era una tarjeta que ya cambiaste, retomar es un toque. No se te cobró nada durante tu ausencia.",
      cta: "Reactivar Pick1 Pro", panelLabel: "REGISTRO REAL DESDE EL FIN DE TU ACCESO", unsub: "Darse de baja" },
    pt: { greet: "Olá", subject: "A tua subscri&ccedil;&atilde;o Pick1 parou por um pagamento recusado",
      preheader: "Não foi um cancelamento. A cobrança não passou.",
      badge: "FATURA&Ccedil;&Atilde;O &middot; N&Atilde;O &Eacute; UM CANCELAMENTO", h1: "N&Atilde;O FOSTE TU", h2: "QUE CANCELASTE.",
      p1: "A tua subscrição Pick1 Pro terminou porque uma cobrança falhou, não porque escolheste sair. A Apple tentou de novo, o pagamento nunca passou, e o acesso parou.",
      p2: "Isto foi o que o modelo indicou entretanto, vitórias e derrotas no mesmo número. Se era um cartão que já substituíste, retomar é um toque. Nada te foi cobrado durante a tua ausência.",
      cta: "Retomar o Pick1 Pro", panelLabel: "REGISTO REAL DESDE O FIM DO TEU ACESSO", unsub: "Cancelar subscrição" },
  },
  churned: {
    en: { greet: "Hi", subject: "What the model called while you were gone",
      preheader: "Wins and losses, both. Same as always.",
      badge: "YOUR ACCOUNT &middot; LAPSED", h1: "HERE'S WHAT", h2: "YOU MISSED.",
      p1: "Your Pick1 Pro access ended a while back. The model kept running, and every call it made was logged publicly before kickoff, exactly as it was when you were subscribed.",
      p2: "That record is below, wins and losses together. If it reads well to you, coming back takes one tap. If it doesn't, that is a fair reason to stay away and we would rather you saw it.",
      cta: "See today's board", panelLabel: "SETTLED RECORD SINCE YOU LEFT", unsub: "Unsubscribe" },
    fr: { greet: "Salut", subject: "Ce que le mod&egrave;le a annonc&eacute; pendant ton absence",
      preheader: "Victoires et défaites, les deux. Comme toujours.",
      badge: "TON COMPTE &middot; EXPIR&Eacute;", h1: "VOIL&Agrave; CE QUE", h2: "TU AS MANQU&Eacute;.",
      p1: "Ton accès Pick1 Pro s'est terminé il y a un moment. Le modèle a continué de tourner, et chaque pronostic a été enregistré publiquement avant le coup d'envoi, exactement comme quand tu étais abonné.",
      p2: "Ce bilan est ci dessous, victoires et défaites ensemble. S'il te parle, revenir prend un geste. Sinon, c'est une raison valable de rester à l'écart, et on préfère que tu le voies.",
      cta: "Voir le tableau du jour", panelLabel: "BILAN R&Eacute;EL DEPUIS TON D&Eacute;PART", unsub: "Se désinscrire" },
    es: { greet: "Hola", subject: "Lo que el modelo anunci&oacute; mientras no estabas",
      preheader: "Aciertos y fallos, los dos. Como siempre.",
      badge: "TU CUENTA &middot; EXPIRADA", h1: "ESTO ES LO", h2: "QUE TE PERDISTE.",
      p1: "Tu acceso Pick1 Pro terminó hace un tiempo. El modelo siguió funcionando, y cada pronóstico quedó registrado públicamente antes del inicio, igual que cuando estabas suscrito.",
      p2: "Ese registro está abajo, aciertos y fallos juntos. Si te convence, volver es un toque. Si no, es una razón legítima para no volver, y preferimos que lo veas.",
      cta: "Ver el tablero de hoy", panelLabel: "REGISTRO REAL DESDE QUE TE FUISTE", unsub: "Darse de baja" },
    pt: { greet: "Olá", subject: "O que o modelo indicou enquanto estiveste fora",
      preheader: "Vitórias e derrotas, as duas. Como sempre.",
      badge: "A TUA CONTA &middot; EXPIRADA", h1: "ISTO &Eacute; O QUE", h2: "PERDESTE.",
      p1: "O teu acesso Pick1 Pro terminou há algum tempo. O modelo continuou a correr, e cada palpite ficou registado publicamente antes do apito inicial, tal como quando eras subscritor.",
      p2: "Esse registo está abaixo, vitórias e derrotas juntas. Se te convencer, voltar é um toque. Se não, é uma razão legítima para ficares de fora, e preferimos que a vejas.",
      cta: "Ver o quadro de hoje", panelLabel: "REGISTO REAL DESDE QUE SA&Iacute;STE", unsub: "Cancelar subscrição" },
  },
  trial: {
    en: { greet: "Hi", subject: "You gave Pick1 three days. Here's the longer version.",
      preheader: "The settled record since your trial ended.",
      badge: "YOUR TRIAL &middot; ENDED", h1: "THREE DAYS", h2: "WASN'T MUCH.",
      p1: "You tried Pick1 and stopped before the first charge. Fair enough. Three days is roughly three settled calls, nowhere near enough to judge a model on.",
      p2: "So here is the longer sample, every call settled since your trial ended, wins and losses in the same number. Judge it on that instead.",
      cta: "See today's board", panelLabel: "SETTLED SINCE YOUR TRIAL ENDED", unsub: "Unsubscribe" },
    fr: { greet: "Salut", subject: "Tu as donn&eacute; trois jours &agrave; Pick1. Voici la version longue.",
      preheader: "Le bilan réel depuis la fin de ton essai.",
      badge: "TON ESSAI &middot; TERMIN&Eacute;", h1: "TROIS JOURS,", h2: "C'EST COURT.",
      p1: "Tu as essayé Pick1 et tu t'es arrêté avant le premier prélèvement. C'est légitime. Trois jours, c'est environ trois pronostics réglés, très loin de ce qu'il faut pour juger un modèle.",
      p2: "Voici donc l'échantillon plus large, tous les pronostics réglés depuis la fin de ton essai, victoires et défaites dans le même chiffre. Juge sur cette base.",
      cta: "Voir le tableau du jour", panelLabel: "R&Eacute;GL&Eacute;S DEPUIS LA FIN DE TON ESSAI", unsub: "Se désinscrire" },
    es: { greet: "Hola", subject: "Le diste tres d&iacute;as a Pick1. Aqu&iacute; va la versi&oacute;n larga.",
      preheader: "El registro real desde que terminó tu prueba.",
      badge: "TU PRUEBA &middot; TERMINADA", h1: "TRES D&Iacute;AS", h2: "ES POCO.",
      p1: "Probaste Pick1 y lo dejaste antes del primer cobro. Es razonable. Tres días son unos tres pronósticos resueltos, muy lejos de lo necesario para juzgar un modelo.",
      p2: "Aquí va la muestra más larga, todos los pronósticos resueltos desde que terminó tu prueba, aciertos y fallos en la misma cifra. Júzgalo con eso.",
      cta: "Ver el tablero de hoy", panelLabel: "RESUELTOS DESDE EL FIN DE TU PRUEBA", unsub: "Darse de baja" },
    pt: { greet: "Olá", subject: "Deste tr&ecirc;s dias ao Pick1. Aqui vai a vers&atilde;o longa.",
      preheader: "O registo real desde que a tua experiência terminou.",
      badge: "A TUA EXPERI&Ecirc;NCIA &middot; TERMINADA", h1: "TR&Ecirc;S DIAS", h2: "&Eacute; POUCO.",
      p1: "Experimentaste o Pick1 e paraste antes da primeira cobrança. É justo. Três dias são cerca de três palpites resolvidos, muito longe do necessário para julgar um modelo.",
      p2: "Aqui vai a amostra maior, todos os palpites resolvidos desde que a tua experiência terminou, vitórias e derrotas no mesmo número. Julga por aí.",
      cta: "Ver o quadro de hoje", panelLabel: "RESOLVIDOS DESDE O FIM DA EXPERI&Ecirc;NCIA", unsub: "Cancelar subscrição" },
  },
};

// T2. Every factual claim here is a count read out of `picks` at send time and
// rendered in the panel, so the prose never has to assert coverage it cannot
// back up on the day it sends.
const T2C: Record<string, Copy> = {
  en: { greet: "Hi", subject: "The board is wider than when you left",
    preheader: "Every sport that carried a call in the last two weeks.",
    badge: "SINCE YOU LEFT &middot; WHAT CHANGED", h1: "THE BOARD", h2: "GOT WIDER.",
    p1: "When you were last in the app, most days came down to a couple of leagues. That is no longer what the board looks like. Every sport in season now gets read on its own, so a single day can carry calls across tennis, combat, baseball, soccer, cricket, golf, football and motorsport.",
    p2: "Below is exactly which sports carried a call in the last fourteen days, and how many calls have been logged since your access ended. Every one of them went up before the game started, with the confidence the model put on it, so you can check it after the fact rather than take our word for it.",
    cta: "See today's board", panelLabel: "COVERED IN THE LAST 14 DAYS", unsub: "Unsubscribe" },
  fr: { greet: "Salut", subject: "Le tableau est plus large qu'&agrave; ton d&eacute;part",
    preheader: "Tous les sports qui ont porté un pronostic ces deux dernières semaines.",
    badge: "DEPUIS TON D&Eacute;PART &middot; CE QUI A CHANG&Eacute;", h1: "LE TABLEAU", h2: "S'EST &Eacute;LARGI.",
    p1: "La dernière fois que tu étais dans l'app, la plupart des journées se résumaient à deux ou trois championnats. Ce n'est plus la tête du tableau aujourd'hui. Chaque sport en saison est analysé pour lui même, donc une seule journée peut porter des pronostics sur le tennis, le combat, le baseball, le foot, le cricket, le golf, le football américain et le sport auto.",
    p2: "Ci dessous, exactement quels sports ont porté un pronostic ces quatorze derniers jours, et combien de pronostics ont été enregistrés depuis la fin de ton accès. Chacun est publié avant le coup d'envoi, avec la confiance que le modèle lui a donnée, pour que tu puisses vérifier après coup au lieu de nous croire sur parole.",
    cta: "Voir le tableau du jour", panelLabel: "COUVERTS SUR LES 14 DERNIERS JOURS", unsub: "Se désinscrire" },
  es: { greet: "Hola", subject: "El tablero es m&aacute;s amplio que cuando te fuiste",
    preheader: "Todos los deportes con pronóstico en las últimas dos semanas.",
    badge: "DESDE QUE TE FUISTE &middot; LO QUE CAMBI&Oacute;", h1: "EL TABLERO", h2: "SE AMPLI&Oacute;.",
    p1: "La última vez que estuviste en la app, casi todos los días se reducían a un par de ligas. Ya no es así. Cada deporte en temporada se analiza por su cuenta, así que un solo día puede llevar pronósticos de tenis, combate, béisbol, fútbol, críquet, golf, fútbol americano y automovilismo.",
    p2: "Abajo está exactamente qué deportes llevaron pronóstico en los últimos catorce días, y cuántos se han registrado desde que terminó tu acceso. Todos se publican antes del inicio, con la confianza que el modelo les dio, para que puedas comprobarlo después en lugar de creernos.",
    cta: "Ver el tablero de hoy", panelLabel: "CUBIERTOS EN LOS &Uacute;LTIMOS 14 D&Iacute;AS", unsub: "Darse de baja" },
  pt: { greet: "Olá", subject: "O quadro est&aacute; mais largo do que quando sa&iacute;ste",
    preheader: "Todos os desportos com palpite nas últimas duas semanas.",
    badge: "DESDE QUE SA&Iacute;STE &middot; O QUE MUDOU", h1: "O QUADRO", h2: "ALARGOU.",
    p1: "Da última vez que estiveste na app, quase todos os dias se resumiam a duas ou três ligas. Já não é esse o aspeto do quadro. Cada desporto em época é lido por si, por isso um único dia pode levar palpites de ténis, combate, basebol, futebol, críquete, golfe, futebol americano e automobilismo.",
    p2: "Em baixo está exatamente que desportos levaram palpite nos últimos catorze dias, e quantos foram registados desde que o teu acesso terminou. Todos são publicados antes do apito inicial, com a confiança que o modelo lhes deu, para poderes verificar depois em vez de acreditares em nós.",
    cta: "Ver o quadro de hoje", panelLabel: "COBERTOS NOS &Uacute;LTIMOS 14 DIAS", unsub: "Cancelar subscrição" },
};

// T3. {offer} is replaced with WINBACK_OFFER_LABEL, and the prose around it
// is deliberately shape neutral: it says an offer is waiting and names it,
// never "free" or "at no charge". A discount and a free month therefore read
// correctly through the same copy, and changing the offer in App Store Connect
// changes only the label, with no copy edit and no risk of a stale promise.
const T3C: Record<string, Copy> = {
  en: { greet: "Hi", subject: "{offer} on Pick1 Pro",
    preheader: "Long enough to actually read the model.",
    badge: "WIN BACK OFFER &middot; APPLE ID", h1: "ENOUGH TIME", h2: "TO JUDGE IT.",
    p1: "Two emails, two honest numbers, and this is the last one. If the record was worth a second look, there is a returning subscriber offer waiting on your Apple ID: {offer}.",
    p2: "Long enough to watch a real run of calls settle, the good ones and the bad ones, instead of the three you saw the first time. Cancelling takes one tap in your Apple settings.",
    cta: "Claim the offer", panelLabel: "SETTLED RECORD, LAST 30 DAYS", unsub: "Unsubscribe" },
  fr: { greet: "Salut", subject: "{offer} sur Pick1 Pro",
    preheader: "Assez long pour vraiment lire le modèle.",
    badge: "OFFRE DE RETOUR &middot; IDENTIFIANT APPLE", h1: "LE TEMPS", h2: "DE JUGER.",
    p1: "Deux emails, deux chiffres honnêtes, et c'est le dernier. Si le bilan méritait un second regard, une offre de retour t'attend sur ton identifiant Apple : {offer}.",
    p2: "Assez long pour voir une vraie série de pronostics se régler, les bons comme les mauvais, au lieu des trois que tu avais vus la première fois. Annuler prend un geste dans tes réglages Apple.",
    cta: "Activer l'offre", panelLabel: "BILAN R&Eacute;EL, 30 DERNIERS JOURS", unsub: "Se désinscrire" },
  es: { greet: "Hola", subject: "{offer} en Pick1 Pro",
    preheader: "Tiempo suficiente para leer el modelo de verdad.",
    badge: "OFERTA DE REGRESO &middot; ID DE APPLE", h1: "TIEMPO", h2: "PARA JUZGAR.",
    p1: "Dos correos, dos cifras honestas, y este es el último. Si el registro merecía una segunda mirada, tienes una oferta de regreso esperando en tu ID de Apple: {offer}.",
    p2: "Suficiente para ver resolverse una serie real de pronósticos, los buenos y los malos, en vez de los tres que viste la primera vez. Cancelar es un toque en tus ajustes de Apple.",
    cta: "Activar la oferta", panelLabel: "REGISTRO REAL, &Uacute;LTIMOS 30 D&Iacute;AS", unsub: "Darse de baja" },
  pt: { greet: "Olá", subject: "{offer} no Pick1 Pro",
    preheader: "Tempo suficiente para ler mesmo o modelo.",
    badge: "OFERTA DE REGRESSO &middot; ID APPLE", h1: "TEMPO", h2: "PARA JULGAR.",
    p1: "Dois emails, dois números honestos, e este é o último. Se o registo merecia um segundo olhar, tens uma oferta de regresso à espera no teu ID Apple: {offer}.",
    p2: "Tempo suficiente para ver resolver uma série real de palpites, os bons e os maus, em vez dos três que viste da primeira vez. Cancelar é um toque nas tuas definições Apple.",
    cta: "Activar a oferta", panelLabel: "REGISTO REAL, &Uacute;LTIMOS 30 DIAS", unsub: "Cancelar subscrição" },
};

// The offer label is the only phrase in T3 that describes the offer's shape,
// and it has to agree with what App Store Connect actually grants. Set the
// English one, and a per language override wherever the literal translation is
// not what you would say ("1 month" / "1 mois" / "1 mes" / "1 mês").
const OFFER_LABEL: Record<string, string> = {
  en: OFFER_LABEL_EN ?? "",
  fr: Deno.env.get("WINBACK_OFFER_LABEL_FR") ?? OFFER_LABEL_EN ?? "",
  es: Deno.env.get("WINBACK_OFFER_LABEL_ES") ?? OFFER_LABEL_EN ?? "",
  pt: Deno.env.get("WINBACK_OFFER_LABEL_PT") ?? OFFER_LABEL_EN ?? "",
};

const SPORT_NAME: Record<string, Record<string, string>> = {
  en: { basketball: "Basketball", football: "Football", soccer: "Soccer", hockey: "Hockey", baseball: "Baseball", combat: "Fight", f1: "Race", tennis: "Tennis", cricket: "Cricket", golf: "Golf", rugby: "Rugby", afl: "AFL" },
  fr: { basketball: "Basket", football: "Football US", soccer: "Foot", hockey: "Hockey", baseball: "Baseball", combat: "Combat", f1: "Course", tennis: "Tennis", cricket: "Cricket", golf: "Golf", rugby: "Rugby", afl: "AFL" },
  es: { basketball: "Baloncesto", football: "Fútbol americano", soccer: "Fútbol", hockey: "Hockey", baseball: "Béisbol", combat: "Combate", f1: "Carrera", tennis: "Tenis", cricket: "Críquet", golf: "Golf", rugby: "Rugby", afl: "AFL" },
  pt: { basketball: "Basquetebol", football: "Futebol americano", soccer: "Futebol", hockey: "Hóquei", baseball: "Basebol", combat: "Combate", f1: "Corrida", tennis: "Ténis", cricket: "Críquete", golf: "Golfe", rugby: "Râguebi", afl: "AFL" },
};
const LOGGED_SINCE: Record<string, string> = {
  en: "calls logged since your access ended",
  fr: "pronostics enregistrés depuis la fin de ton accès",
  es: "pronósticos registrados desde el fin de tu acceso",
  pt: "palpites registados desde o fim do teu acesso",
};

const STOREFRONT_LANG: Record<string, string> = {
  FRA: "fr", BEL: "fr", LUX: "fr", MCO: "fr", MAR: "fr", TUN: "fr", DZA: "fr", CIV: "fr", SEN: "fr", CMR: "fr", COD: "fr",
  MEX: "es", ESP: "es", COL: "es", CHL: "es", ARG: "es", ECU: "es", PER: "es", HND: "es", DOM: "es",
  GTM: "es", CRI: "es", PAN: "es", URY: "es", PRY: "es", BOL: "es", VEN: "es", SLV: "es", NIC: "es",
  BRA: "pt", PRT: "pt", AGO: "pt", MOZ: "pt", CPV: "pt",
};
const langFor = (sf: string | null): string => (sf && STOREFRONT_LANG[sf]) || "en";

const esc = (s: string) =>
  s.replace(/&(?![a-zA-Z]+;|#\d+;)/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

// ---------------------------------------------------------------- template

type Rec = { wins: number; total: number; pct: number; sample: { pick: string; won: boolean }[] };

const ROW = (l: string, r: string, tone: string) =>
  `<tr><td style="padding:7px 0;border-bottom:1px solid #22252b;font-family:Archivo,Arial,sans-serif;font-size:14px;color:#f5f3ee;">${l}</td>` +
  `<td align="right" style="padding:7px 0;border-bottom:1px solid #22252b;font-family:'Courier New',monospace;font-size:13px;font-weight:700;color:${tone};">${r}</td></tr>`;

/// The settled record panel: a big wins-over-total, then the three calls the
/// model was MOST confident about, whatever they did. Showing the top wins only
/// would be exactly the tipster behaviour this product exists to argue against.
function recordPanel(label: string, rec: Rec): string {
  const rows = rec.sample.map((s) => ROW(esc(s.pick), s.won ? "WON" : "LOST", s.won ? "#4ade80" : "#6e6f75")).join("");
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:26px 0 0;border:1px solid #22252b;">
    <tr><td style="padding:16px 18px 10px;">
      <div style="font-family:Archivo,Arial,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.18em;text-transform:uppercase;color:#6e6f75;">${label}</div>
      <div style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:34px;color:#f5f3ee;padding-top:6px;">${rec.wins}<span style="color:#6e6f75;"> / ${rec.total}</span> <span style="font-size:18px;color:#d4ff3a;">${rec.pct}%</span></div>
    </td></tr>
    ${rows ? `<tr><td style="padding:2px 18px 16px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">${rows}</table></td></tr>` : ""}
  </table>`;
}

/// The coverage panel: which sports actually carried a call in the last two
/// weeks, as chips, plus the volume logged since this person left.
function coveragePanel(label: string, lang: string, sports: string[], logged: number): string {
  const names = SPORT_NAME[lang] ?? SPORT_NAME.en;
  const chips = sports.map((s) =>
    `<span style="display:inline-block;border:1px solid #2c3038;color:#f5f3ee;font-family:Archivo,Arial,sans-serif;font-size:12px;padding:5px 10px;margin:0 6px 6px 0;">${esc(names[s] ?? s)}</span>`
  ).join("");
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:26px 0 0;border:1px solid #22252b;">
    <tr><td style="padding:16px 18px 6px;">
      <div style="font-family:Archivo,Arial,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.18em;text-transform:uppercase;color:#6e6f75;">${label}</div>
      <div style="padding-top:10px;">${chips}</div>
    </td></tr>
    <tr><td style="padding:4px 18px 16px;border-top:1px solid #22252b;">
      <div style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:30px;color:#d4ff3a;padding-top:10px;">${logged}</div>
      <div style="font-family:Archivo,Arial,sans-serif;font-size:12px;color:#b9b7b0;">${esc(LOGGED_SINCE[lang] ?? LOGGED_SINCE.en)}</div>
    </td></tr>
  </table>`;
}

function emailHtml(c: Copy, lang: string, panel: string, ctaUrl: string, unsubUrl: string, firstName: string | null): string {
  const hello = firstName
    ? `<p style="margin:0 0 2px;font-family:Archivo,Arial,sans-serif;font-size:15px;color:#b9b7b0;">${esc(c.greet)} ${esc(firstName)},</p>`
    : "";
  return `<!doctype html>
<html lang="${lang}" dir="ltr">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark"><meta name="supported-color-schemes" content="dark only"><title>Pick1</title>
<link href="https://fonts.googleapis.com/css2?family=Anton&family=Archivo:wght@400;700&display=swap" rel="stylesheet"></head>
<body style="margin:0;padding:0;background-color:#0a0b0d;" bgcolor="#0a0b0d">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;visibility:hidden;opacity:0;color:transparent;height:0;width:0;">${esc(c.preheader)}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#0a0b0d" style="background-color:#0a0b0d;">
    <tr><td align="center" style="padding:32px 16px 48px;">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:600px;max-width:100%;">
        <tr><td align="left" style="padding:0 0 20px;">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
            <td style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:26px;letter-spacing:0.04em;color:#f5f3ee;padding-right:8px;">PICK</td>
            <td><table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
              <td bgcolor="#d4ff3a" align="center" valign="middle" style="background-color:#d4ff3a;width:30px;height:30px;border-radius:50%;font-family:Anton,'Arial Black',Impact,sans-serif;font-size:18px;line-height:30px;color:#0a0b0d;mso-line-height-rule:exactly;">1</td>
            </tr></table></td>
          </tr></table>
        </td></tr>
        <tr><td bgcolor="#d4ff3a" style="background-color:#d4ff3a;height:4px;line-height:4px;font-size:4px;">&nbsp;</td></tr>
        <tr><td bgcolor="#101114" align="left" style="background-color:#101114;border:1px solid #22252b;border-top:0;padding:36px 32px;">
          ${hello}
          <span style="display:inline-block;border:1px solid #d4ff3a;color:#d4ff3a;font-family:Archivo,Arial,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.22em;text-transform:uppercase;padding:6px 12px;margin-top:10px;">${c.badge}</span>
          <div style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:38px;line-height:1.08;color:#f5f3ee;text-transform:uppercase;padding:22px 0 6px;">${c.h1}<br><span style="color:#d4ff3a;">${c.h2}</span></div>
          <p style="margin:14px 0 0;font-family:Archivo,Arial,sans-serif;font-size:16px;line-height:1.7;color:#f5f3ee;">${esc(c.p1)}</p>
          <p style="margin:12px 0 0;font-family:Archivo,Arial,sans-serif;font-size:15px;line-height:1.7;color:#b9b7b0;">${esc(c.p2)}</p>
          ${panel}
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:26px 0 4px;"><tr>
            <td bgcolor="#d4ff3a" style="background-color:#d4ff3a;border-radius:4px;">
              <a href="${ctaUrl}" style="display:inline-block;font-family:Anton,'Arial Black',Impact,sans-serif;font-size:17px;letter-spacing:0.06em;text-transform:uppercase;color:#0a0b0d;text-decoration:none;padding:14px 30px;">${esc(c.cta)}</a>
            </td></tr></table>
        </td></tr>
        <tr><td align="left" style="padding:22px 8px 0;">
          <p style="margin:0;font-family:Archivo,Arial,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.22em;text-transform:uppercase;color:#6e6f75;">PICK<span style="color:#d4ff3a;">1</span>&nbsp;&middot;&nbsp;EVERY PICK, PUBLICLY LOGGED</p>
          <p style="margin:10px 0 0;font-family:Archivo,Arial,sans-serif;font-size:11px;line-height:1.6;color:#6e6f75;">AI predictions for information &amp; entertainment, not betting advice. <a href="${unsubUrl}" style="color:#6e6f75;text-decoration:underline;">${esc(c.unsub)}</a>.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;
}

// ---------------------------------------------------------------- handler

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (!req.headers.get("authorization")) return new Response("Unauthorized", { status: 401 });

  let dryRun = false, only: string[] | undefined, limit = 200, dailyCap = DEFAULT_DAILY_CAP;
  try {
    const b = await req.json().catch(() => ({}));
    ({ dryRun = false, only, limit = 200, dailyCap = DEFAULT_DAILY_CAP } = b ?? {});
  } catch { /* cron posts {} */ }

  const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
  const report: Record<string, unknown> = { ranAt: new Date().toISOString(), dryRun };

  // ---- shared data, computed once per run ----------------------------

  const recordCache = new Map<string, Rec>();
  async function recordSince(iso: string): Promise<Rec> {
    const day = iso.slice(0, 10);
    if (recordCache.has(day)) return recordCache.get(day)!;
    const { data, error } = await db.from("picks")
      .select("pick, result, probability, game_date")
      .gte("game_date", day).in("result", ["win", "loss"])
      .order("probability", { ascending: false }).limit(2000);
    if (error) throw new Error(`picks read failed: ${error.message}`);
    const rows = data ?? [];
    const wins = rows.filter((r: any) => r.result === "win").length;
    const total = rows.length;
    const sample = rows.slice(0, 3).map((r: any) => ({ pick: r.pick as string, won: r.result === "win" }));
    const rec: Rec = { wins, total, pct: total ? Math.round((wins / total) * 100) : 0, sample };
    recordCache.set(day, rec);
    return rec;
  }

  const loggedCache = new Map<string, number>();
  async function loggedSince(iso: string): Promise<number> {
    const day = iso.slice(0, 10);
    if (loggedCache.has(day)) return loggedCache.get(day)!;
    const { count, error } = await db.from("picks")
      .select("id", { count: "exact", head: true }).gte("game_date", day);
    if (error) throw new Error(`picks count failed: ${error.message}`);
    const n = count ?? 0;
    loggedCache.set(day, n);
    return n;
  }

  // Which sports actually carried a call in the last fourteen days. T2's only
  // factual claim, and it is read rather than asserted so an out of season
  // sport is simply absent instead of being promised.
  let coveredSports: string[] = [];
  async function loadCoverage() {
    const since = new Date(Date.now() - 14 * 86400e3).toISOString().slice(0, 10);
    const { data, error } = await db.from("picks").select("sport").gte("game_date", since).limit(5000);
    if (error) throw new Error(`coverage read failed: ${error.message}`);
    const seen = new Set<string>();
    for (const r of data ?? []) if (r.sport) seen.add(r.sport as string);
    const ORDER = ["soccer", "basketball", "football", "baseball", "hockey", "tennis", "combat", "f1", "cricket", "golf", "rugby", "afl"];
    coveredSports = ORDER.filter((s) => seen.has(s)).concat([...seen].filter((s) => !ORDER.includes(s)));
  }

  // Warming budget. Counted from what has ALREADY gone out today across every
  // touch, so an hourly cron cannot stack runs past the cap.
  const todayStart = new Date(); todayStart.setUTCHours(0, 0, 0, 0);
  const { count: sentToday } = await db.from("email_log")
    .select("id", { count: "exact", head: true })
    .like("email_type", "winback_%").eq("status", "sent").gte("sent_at", todayStart.toISOString());
  let budget = Math.max(0, dailyCap - (sentToday ?? 0));
  report.sentToday = sentToday ?? 0;
  report.budget = budget;

  // ---- one send ------------------------------------------------------

  type Person = { user_id: string; dedupe: string; since: string; lang: string };

  async function deliver(touch: Touch, seg: Seg | null, people: Person[]) {
    if (!people.length) return { candidates: 0, sent: 0, reason: "no recipients" };
    if (touch === "t3" && (!OFFER_URL || !OFFER_LABEL_EN)) {
      return { candidates: people.length, sent: 0,
        blocked: "WINBACK_OFFER_URL / WINBACK_OFFER_LABEL not set, refusing to describe an offer that does not exist" };
    }
    if (!RESEND_KEY && !dryRun) {
      return { candidates: people.length, sent: 0, blocked: "RESEND_API_KEY not set, nothing can be delivered" };
    }

    const ids = people.map((p) => p.user_id);
    const { data: signups, error: sErr } = await db.from("signups").select("id, email, first_name").in("id", ids);
    if (sErr) throw new Error(`signups read failed: ${sErr.message}`);
    const infoOf = new Map((signups ?? []).map((s: any) => [s.id, s]));

    if (!dryRun) {
      const { error } = await db.from("email_preferences")
        .upsert(ids.map((id) => ({ user_id: id })), { onConflict: "user_id", ignoreDuplicates: true });
      if (error) throw new Error(`email_preferences upsert failed: ${error.message}`);
    }
    const { data: prefs, error: pErr } = await db.from("email_preferences")
      .select("user_id, newsletter, unsubscribe_token").in("user_id", ids);
    if (pErr) throw new Error(`email_preferences read failed: ${pErr.message}`);
    const prefOf = new Map((prefs ?? []).map((p: any) => [p.user_id, p]));

    const emailType = touch === "t1" ? `winback_t1_${seg}` : `winback_${touch}`;
    let sent = 0, failed = 0, skippedOptOut = 0, skippedNoEmail = 0, alreadySent = 0, cappedOut = 0;
    const errors: string[] = [];
    const preview: any[] = [];

    for (const p of people) {
      if (!dryRun && budget <= 0) { cappedOut++; continue; }
      const info = infoOf.get(p.user_id);
      const email = info?.email as string | undefined;
      if (!email) { skippedNoEmail++; continue; }
      const pref = prefOf.get(p.user_id);
      if (pref && pref.newsletter === false) { skippedOptOut++; continue; }

      const lang = p.lang;
      const first = (info?.first_name as string | null)?.trim() || null;
      const label = OFFER_LABEL[lang] || OFFER_LABEL_EN || "";
      const raw = touch === "t1" ? (T1[seg!][lang] ?? T1[seg!].en)
        : touch === "t2" ? (T2C[lang] ?? T2C.en)
        : (T3C[lang] ?? T3C.en);
      const copy: Copy = touch === "t3"
        ? { ...raw, subject: raw.subject.replace(/\{offer\}/g, label), cta: raw.cta.replace(/\{offer\}/g, label),
            p1: raw.p1.replace(/\{offer\}/g, label), p2: raw.p2.replace(/\{offer\}/g, label) }
        : raw;

      let panel: string;
      if (touch === "t2") {
        panel = coveragePanel(copy.panelLabel, lang, coveredSports, await loggedSince(p.since));
      } else if (touch === "t3") {
        const d30 = new Date(Date.now() - 30 * 86400e3).toISOString();
        panel = recordPanel(copy.panelLabel, await recordSince(d30));
      } else {
        panel = recordPanel(copy.panelLabel, await recordSince(p.since));
      }
      const ctaUrl = touch === "t3" ? OFFER_URL! : APP_URL;

      if (dryRun) {
        preview.push({ lang, first, subject: copy.subject, since: p.since.slice(0, 10),
          ...(touch === "t2" ? { sports: coveredSports.length } : {}) });
        continue;
      }

      // Claim first, send second: a crash between the two loses the email
      // rather than duplicating it, which is the right way round.
      const { data: claim, error: cErr } = await db.from("email_log")
        .upsert({ user_id: p.user_id, email_type: emailType, dedupe_key: p.dedupe, status: "pending" },
          { onConflict: "user_id,email_type,dedupe_key", ignoreDuplicates: true })
        .select("id");
      if (cErr) { errors.push(`email_log claim: ${cErr.message}`); continue; }
      if (!claim || !claim.length) { alreadySent++; continue; }
      const logId = claim[0].id;

      const unsubUrl = `${UNSUB_BASE}?token=${pref?.unsubscribe_token ?? ""}&list=newsletter`;
      try {
        const r = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
          body: JSON.stringify({
            from: EMAIL_FROM, to: [email], subject: copy.subject,
            html: emailHtml(copy, lang, panel, ctaUrl, unsubUrl, first),
            headers: {
              "List-Unsubscribe": `<${unsubUrl}>`,
              "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
            },
          }),
        });
        if (!r.ok) throw new Error(`Resend ${r.status}: ${(await r.text()).slice(0, 300)}`);
        await db.from("email_log").update({ status: "sent", sent_at: new Date().toISOString() }).eq("id", logId);
        sent++; budget--;
        await sleep(SEND_GAP_MS);
      } catch (e) {
        await db.from("email_log").update({ status: "failed", error: String(e).slice(0, 500) }).eq("id", logId);
        failed++;
      }
    }
    return { candidates: people.length, sent, failed, alreadySent, skippedOptOut, skippedNoEmail, cappedOut,
      ...(dryRun ? { preview: preview.slice(0, 6) } : {}), ...(errors.length ? { errors } : {}) };
  }

  // ---- who is eligible -----------------------------------------------

  const lapsedBase = () => db.from("subscriptions")
    .select("user_id, original_transaction_id, expires_date, updated_at, raw, last_notification_type, last_notification_subtype, is_trial")
    .eq("environment", "Production").eq("status", "expired")
    .is("revocation_date", null).not("user_id", "is", null);

  const toPerson = (r: any): Person => ({
    user_id: r.user_id,
    dedupe: r.original_transaction_id ?? r.user_id,
    since: r.expires_date ?? r.updated_at ?? new Date(Date.now() - 30 * 86400e3).toISOString(),
    lang: langFor(r.raw?.transaction?.storefront ?? null),
  });

  /// Everyone among the lapsed who ever held a NON trial subscription.
  ///
  /// This is the gate on T3, and it is not a nicety. Apple's win back offers
  /// have a Minimum Paid Duration whose floor is one month, so a customer who
  /// started the three day trial and cancelled before it converted cannot
  /// redeem one. Measured 2026-09-02: of 563 lapsed people, 85 ever paid and
  /// 478 are trial only. Sending the offer email to the 478 would send 85% of
  /// the audience to a redemption link that does nothing for them, which is
  /// worse than sending them nothing. Their sequence ends at T2.
  ///
  /// If the offer is ever replaced with an Offer Code, which has no paid
  /// duration requirement, this gate is the one thing to remove.
  async function everPaidUsers(): Promise<Set<string>> {
    const { data, error } = await db.from("subscriptions")
      .select("user_id").eq("environment", "Production").eq("is_trial", false)
      .not("user_id", "is", null).limit(20000);
    if (error) throw new Error(`subscriptions read failed: ${error.message}`);
    return new Set((data ?? []).map((r: any) => r.user_id as string));
  }

  /// Everyone who has a DELIVERED email of `afterType` older than `days`, and
  /// no row at all for `thisType`. The join is done in code because email_log
  /// is small and this keeps the eligibility rule readable in one place.
  async function dueForFollowUp(afterTypes: string[], thisType: string, days: number): Promise<Set<string>> {
    const cutoff = new Date(Date.now() - days * 86400e3).toISOString();
    const { data: done, error: e1 } = await db.from("email_log")
      .select("user_id").in("email_type", afterTypes).eq("status", "sent").lte("sent_at", cutoff);
    if (e1) throw new Error(`email_log read failed: ${e1.message}`);
    const { data: already, error: e2 } = await db.from("email_log").select("user_id").eq("email_type", thisType);
    if (e2) throw new Error(`email_log read failed: ${e2.message}`);
    const skip = new Set((already ?? []).map((r: any) => r.user_id));
    const out = new Set<string>();
    for (const r of done ?? []) if (!skip.has(r.user_id)) out.add(r.user_id);
    return out;
  }

  try {
    const want = (t: string) => !Array.isArray(only) || only.includes(t);
    const { data: lapsed, error } = await lapsedBase();
    if (error) throw new Error(`subscriptions read failed: ${error.message}`);

    // One row per user, keeping the most recent subscription record.
    const byUser = new Map<string, any>();
    for (const r of lapsed ?? []) {
      const prev = byUser.get(r.user_id);
      if (!prev || (r.expires_date ?? "") > (prev.expires_date ?? "")) byUser.set(r.user_id, r);
    }
    const all = [...byUser.values()];
    report.lapsedUsers = all.length;

    // TOUCH 3 first, then 2, then 1: finish sequences before starting new ones.
    if (want("t3")) {
      const due = await dueForFollowUp(["winback_t2"], "winback_t3", T3_AFTER_DAYS);
      const paid = await everPaidUsers();
      const eligible = all.filter((r) => due.has(r.user_id) && paid.has(r.user_id));
      const trialOnlySkipped = all.filter((r) => due.has(r.user_id) && !paid.has(r.user_id)).length;
      report.t3TrialOnlySkipped = trialOnlySkipped;
      report.everPaid = all.filter((r) => paid.has(r.user_id)).length;
      report.t3 = await deliver("t3", null, eligible.map(toPerson).slice(0, limit));
    }

    if (want("t2")) {
      await loadCoverage();
      report.coveredSports = coveredSports;
      const due = await dueForFollowUp(
        ["winback_t1_payment", "winback_t1_churned", "winback_t1_trial"], "winback_t2", T2_AFTER_DAYS);
      const people = all.filter((r) => due.has(r.user_id)).map(toPerson).slice(0, limit);
      report.t2 = await deliver("t2", null, people);
    }

    if (want("t1")) {
      // Segment order is the warmth order. Payment failures never made a
      // decision to leave, so they get first claim on the budget; the trial
      // cohort is the largest and the coldest and goes last.
      const claimed = new Set<string>();
      const isPayment = (r: any) => r.last_notification_subtype === "BILLING_RETRY" || r.last_notification_type === "GRACE_PERIOD_EXPIRED";
      const segs: [Seg, (r: any) => boolean][] = [
        ["payment", isPayment],
        ["churned", (r) => !isPayment(r) && r.is_trial === false],
        ["trial", (r) => !isPayment(r) && r.is_trial === true],
      ];
      // Anyone with ANY t1 row already, in any segment, is out.
      const { data: hadT1, error: e } = await db.from("email_log")
        .select("user_id").in("email_type", ["winback_t1_payment", "winback_t1_churned", "winback_t1_trial"]);
      if (e) throw new Error(`email_log read failed: ${e.message}`);
      for (const r of hadT1 ?? []) claimed.add(r.user_id);

      for (const [seg, pred] of segs) {
        const people = all.filter((r) => !claimed.has(r.user_id) && pred(r)).map(toPerson).slice(0, limit);
        for (const p of people) claimed.add(p.user_id);
        (report as any)[`t1_${seg}`] = await deliver("t1", seg, people);
      }
    }

    report.budgetLeft = budget;
    return Response.json(report);
  } catch (e) {
    console.error("winback-email error:", (e as Error).message);
    return Response.json({ error: (e as Error).message, ...report }, { status: 500 });
  }
});
