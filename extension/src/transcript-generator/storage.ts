import browser from '../utils/browser-polyfill';
import {
	TranscriptGeneratorAsrSettings,
	TranscriptGeneratorCookieSettings,
	TranscriptGeneratorGeneralSettings,
	TranscriptGeneratorJobState,
	PlatformCookieConfig,
} from './types';

export const GENERAL_KEY = 'transcript_generator_general_settings';
export const ASR_KEY = 'transcript_generator_asr_settings';
export const COOKIE_KEY = 'transcript_generator_cookie_settings';
export const ACTIVE_JOB_KEY = 'transcript_generator_active_job';
export const PANEL_COLLAPSED_KEY = 'transcript_generator_panel_collapsed';

export const DEFAULT_GENERAL_SETTINGS: TranscriptGeneratorGeneralSettings = {
	enabled: false,
};

export const DEFAULT_ASR_SETTINGS: TranscriptGeneratorAsrSettings = {
	provider: 'faster-whisper',
	whisperModel: 'tiny',
	proxy: '',
};

const emptyPlatformConfig = (): PlatformCookieConfig => ({
	mode: 'off',
	cookies: [],
	updatedAt: null,
	lastValidatedAt: null,
	status: 'empty',
});

export const DEFAULT_COOKIE_SETTINGS: TranscriptGeneratorCookieSettings = {
	bilibili: emptyPlatformConfig(),
	youtube: emptyPlatformConfig(),
};

export async function loadTranscriptGeneratorSettings(): Promise<{
	general: TranscriptGeneratorGeneralSettings;
	asr: TranscriptGeneratorAsrSettings;
	cookies: TranscriptGeneratorCookieSettings;
}> {
	const stored = await browser.storage.local.get([GENERAL_KEY, ASR_KEY, COOKIE_KEY]);
	const storedCookies = (stored[COOKIE_KEY] || {}) as Partial<TranscriptGeneratorCookieSettings>;
	return {
		general: { ...DEFAULT_GENERAL_SETTINGS, ...(stored[GENERAL_KEY] || {}) },
		asr: { ...DEFAULT_ASR_SETTINGS, ...(stored[ASR_KEY] || {}) },
		cookies: {
			bilibili: { ...emptyPlatformConfig(), ...(storedCookies.bilibili || {}) },
			youtube: { ...emptyPlatformConfig(), ...(storedCookies.youtube || {}) },
		},
	};
}

export async function saveGeneralSettings(settings: TranscriptGeneratorGeneralSettings): Promise<void> {
	await browser.storage.local.set({ [GENERAL_KEY]: settings });
}

export async function saveAsrSettings(settings: TranscriptGeneratorAsrSettings): Promise<void> {
	await browser.storage.local.set({ [ASR_KEY]: settings });
}

export async function saveCookieSettings(settings: TranscriptGeneratorCookieSettings): Promise<void> {
	await browser.storage.local.set({ [COOKIE_KEY]: settings });
}

export async function loadActiveJob(): Promise<TranscriptGeneratorJobState | null> {
	const stored = await browser.storage.local.get(ACTIVE_JOB_KEY);
	return (stored[ACTIVE_JOB_KEY] as TranscriptGeneratorJobState | undefined) || null;
}

export async function saveActiveJob(job: TranscriptGeneratorJobState): Promise<void> {
	await browser.storage.local.set({ [ACTIVE_JOB_KEY]: job });
}

export async function loadPanelCollapsed(): Promise<boolean> {
	const stored = await browser.storage.local.get(PANEL_COLLAPSED_KEY);
	return stored[PANEL_COLLAPSED_KEY] === true;
}

export async function savePanelCollapsed(collapsed: boolean): Promise<void> {
	await browser.storage.local.set({ [PANEL_COLLAPSED_KEY]: collapsed });
}
