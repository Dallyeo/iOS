//
//  SearchView.swift
//  Dallyeo
//
//  V04 검색뷰 — 검색바 + 위치칩 + 최근검색/유사검색어
//

import SwiftUI

struct SearchView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SearchViewModel()
    @FocusState private var fieldFocused: Bool

    /// 검색 실행 시 호출 (V05 검색결과뷰 진입에 사용)
    var onSubmit: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            locationChip
                .padding(.top, 8)
                .padding(.bottom, 4)
            content
            Spacer(minLength: 0)
        }
        .background(AppColor.gray200)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            fieldFocused = true
            viewModel.refreshLocationIfAuthorized()
        }
    }

    // MARK: - 검색바

    private var searchBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.gray900)
                    .frame(width: 24, height: 24)
            }

            HStack(spacing: 8) {
                TextField("장소 검색", text: $viewModel.query)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.gray900)
                    .focused($fieldFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit(submit)
                    .onChange(of: viewModel.query) {
                        Task { await viewModel.updateSuggestions() }
                    }

                Button(action: submit) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(viewModel.canSearch ? AppColor.gray900 : AppColor.gray300)
                }
                .disabled(!viewModel.canSearch)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColor.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColor.gray300, lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 위치칩

    private var locationChip: some View {
        HStack {
            Spacer()
            Button {
                viewModel.handleLocationChipTap()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, AppColor.primary)
                    Text(viewModel.locationChipText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColor.primary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 본문 (유사검색어 / 최근검색 / 빈 상태)

    @ViewBuilder
    private var content: some View {
        if viewModel.isTyping {
            suggestionList
        } else if viewModel.recentSearches.isEmpty {
            emptyRecent
        } else {
            recentList
        }
    }

    private var recentList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.recentSearches, id: \.self) { term in
                    Button {
                        let t = viewModel.reuse(term)
                        onSubmit?(t)
                    } label: {
                        HStack {
                            Text(term)
                                .font(.system(size: 16))
                                .foregroundStyle(AppColor.gray900)
                            Spacer()
                            Button {
                                viewModel.removeRecent(term)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppColor.gray500)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
        }
    }

    private var suggestionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.suggestions) { suggestion in
                    Button {
                        viewModel.query = suggestion.name
                        let t = viewModel.submitSearch()
                        if let t { onSubmit?(t) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name)
                                .font(.system(size: 16))
                                .foregroundStyle(AppColor.gray900)
                            if let address = suggestion.address {
                                Text(address)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColor.gray500)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var emptyRecent: some View {
        VStack(spacing: 12) {
            Image(systemName: "ellipsis.message.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.gray300)
            Text("최근 검색한 기록이 없어요")
                .font(.system(size: 14))
                .foregroundStyle(AppColor.gray500)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Actions

    private func submit() {
        guard let term = viewModel.submitSearch() else { return }
        onSubmit?(term)
    }
}
