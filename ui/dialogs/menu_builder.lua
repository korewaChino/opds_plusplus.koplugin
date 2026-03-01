-- UI Menu Builder for OPDS Browser
-- Handles construction of all menu dialogs

local ButtonDialog = require("ui/widget/buttondialog")
local InputDialog = require("ui/widget/inputdialog")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local CheckButton = require("ui/widget/checkbutton")
local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local ffiUtil = require("ffi/util")
local url = require("socket.url")
local _ = require("gettext")
local T = ffiUtil.template

local Constants = require("models.constants")
local StateManager = require("core.state_manager")

local OPDSMenuBuilder = {}

-- Build the main OPDS menu (shown at root level)
-- @param browser table OPDSBrowser instance
-- @return table ButtonDialog widget
function OPDSMenuBuilder.buildOPDSMenu(browser)
	local dialog
	dialog = ButtonDialog:new {
		buttons = {
			{ {
				text = _("Add catalog"),
				callback = function()
					UIManager:close(dialog)
					browser:addEditCatalog()
				end,
				align = "left",
			} },
			{},
			{ {
				text = _("Sync all catalogs"),
				callback = function()
					UIManager:close(dialog)
					NetworkMgr:runWhenConnected(function()
						browser.sync_force = false
						browser:checkSyncDownload()
					end)
				end,
				align = "left",
			} },
			{ {
				text = _("Force sync all catalogs"),
				callback = function()
					UIManager:close(dialog)
					NetworkMgr:runWhenConnected(function()
						browser.sync_force = true
						browser:checkSyncDownload()
					end)
				end,
				align = "left",
			} },
			{ {
				text = _("Set max number of files to sync"),
				callback = function()
					browser:setMaxSyncDownload()
				end,
				align = "left",
			} },
			{ {
				text = _("Set sync folder"),
				callback = function()
					browser:setSyncDir()
				end,
				align = "left",
			} },
			{ {
				text = _("Set file types to sync"),
				callback = function()
					browser:setSyncFiletypes()
				end,
				align = "left",
			} },
		},
		shrink_unneeded_width = true,
		anchor = function()
			return browser.title_bar.left_button.image.dimen
		end,
	}
	return dialog
end

-- Build the facet menu (for catalogs with search/facets)
-- @param browser table OPDSBrowser instance
-- @param catalog_url string Current catalog URL
-- @param has_covers boolean Whether current items have covers
-- @return table ButtonDialog widget
function OPDSMenuBuilder.buildFacetMenu(browser, catalog_url, has_covers)
	local buttons = {}
	local dialog

	-- Add view toggle option FIRST if we have covers
	if has_covers then
		local current_mode = StateManager.getInstance():getDisplayMode()
		local toggle_text
		if current_mode == "list" then
			toggle_text = Constants.ICONS.GRID_VIEW .. " " .. _("Switch to Grid View")
		else
			toggle_text = Constants.ICONS.LIST_VIEW .. " " .. _("Switch to List View")
		end

		table.insert(buttons, { {
			text = toggle_text,
			callback = function()
				UIManager:close(dialog)
				browser:toggleViewMode()
			end,
			align = "left",
		} })
		table.insert(buttons, {})
	end

	-- Add sub-catalog to bookmarks option
	table.insert(buttons, { {
		text = Constants.ICONS.ADD_CATALOG .. " " .. _("Add catalog"),
		callback = function()
			UIManager:close(dialog)
			browser:addSubCatalog(catalog_url)
		end,
		align = "left",
	} })
	table.insert(buttons, {})

	-- Add search option if available
	if browser.search_url then
		table.insert(buttons, { {
			text = Constants.ICONS.SEARCH .. " " .. _("Search"),
			callback = function()
				UIManager:close(dialog)
				browser:searchCatalog(browser.search_url)
			end,
			align = "left",
		} })
		table.insert(buttons, {})
	end

	-- Add facet groups
	if browser.facet_groups then
		for group_name, facets in ffiUtil.orderedPairs(browser.facet_groups) do
			table.insert(buttons, {
				{ text = Constants.ICONS.FILTER .. " " .. group_name, enabled = false, align = "left" }
			})

			for __, link in ipairs(facets) do
				local facet_text = link.title
				if link["thr:count"] then
					facet_text = T(_("%1 (%2)"), facet_text, link["thr:count"])
				end
				if link["opds:activeFacet"] == "true" then
					facet_text = "✓ " .. facet_text
				end
				table.insert(buttons, { {
					text = facet_text,
					callback = function()
						UIManager:close(dialog)
						browser:updateCatalog(url.absolute(catalog_url, link.href))
					end,
					align = "left",
				} })
			end
			table.insert(buttons, {})
		end
	end

	dialog = ButtonDialog:new {
		buttons = buttons,
		shrink_unneeded_width = true,
		anchor = function()
			return browser.title_bar.left_button.image.dimen
		end,
	}

	return dialog
end

-- Build the catalog menu (for catalogs without facets but with covers)
-- @param browser table OPDSBrowser instance
-- @param catalog_url string Current catalog URL
-- @param has_covers boolean Whether current items have covers
-- @return table ButtonDialog widget
function OPDSMenuBuilder.buildCatalogMenu(browser, catalog_url, has_covers)
	local buttons = {}
	local dialog

	-- Add view toggle if we have covers
	if has_covers then
		local current_mode = StateManager.getInstance():getDisplayMode()
		local toggle_text
		if current_mode == "list" then
			toggle_text = Constants.ICONS.GRID_VIEW .. " " .. _("Switch to Grid View")
		else
			toggle_text = Constants.ICONS.LIST_VIEW .. " " .. _("Switch to List View")
		end

		table.insert(buttons, { {
			text = toggle_text,
			callback = function()
				UIManager:close(dialog)
				browser:toggleViewMode()
			end,
			align = "left",
		} })
		table.insert(buttons, {})
	end

	-- Add sub-catalog option
	table.insert(buttons, { {
		text = Constants.ICONS.ADD_CATALOG .. " " .. _("Add catalog"),
		callback = function()
			UIManager:close(dialog)
			browser:addSubCatalog(catalog_url)
		end,
		align = "left",
	} })

	dialog = ButtonDialog:new {
		buttons = buttons,
		shrink_unneeded_width = true,
		anchor = function()
			return browser.title_bar.left_button.image.dimen
		end,
	}

	return dialog
end

-- Build the add/edit catalog dialog
-- @param browser table OPDSBrowser instance
-- @param item table|nil Catalog item to edit (nil for new catalog)
-- @return table MultiInputDialog widget
function OPDSMenuBuilder.buildCatalogEditDialog(browser, item)
	local CatalogManager = require("core.catalog_manager")
	local InfoMessage = require("ui/widget/infomessage")

	local fields = {
		{
			hint = _("Catalog name"),
		},
		{
			hint = _("Catalog URL"),
		},
		{
			hint = _("Username (optional)"),
		},
		{
			hint = _("Password (optional)"),
			text_type = "password",
		},
		{
			hint = _("Sync directory (optional)"),
		},
	}

	local title
	if item then
		title = _("Edit OPDS catalog")
		fields[1].text = item.text
		fields[2].text = item.url
		fields[3].text = item.username
		fields[4].text = item.password
		fields[5].text = item.sync_dir
	else
		title = _("Add OPDS catalog")
	end

	local dialog, check_button_raw_names, check_button_sync_catalog
	dialog = MultiInputDialog:new {
		title = title,
		fields = fields,
		buttons = {
			{
				{
					text = _("Cancel"),
					id = "close",
					callback = function()
						UIManager:close(dialog)
					end,
				},
				{
					text = _("Save"),
					callback = function()
						local text_fields = dialog:getFields()

						-- Validate URL before saving
						local is_valid, validated_url_or_error = CatalogManager.validateCatalogUrl(text_fields[2])

						if not is_valid then
							-- Show error message
							UIManager:show(InfoMessage:new {
								text = _("Invalid URL: ") .. validated_url_or_error,
								timeout = 3,
							})
							return -- Don't close dialog, let user fix it
						end

						-- Validate catalog name
						if not text_fields[1] or text_fields[1]:match("^%s*$") then
							UIManager:show(InfoMessage:new {
								text = _("Catalog name cannot be empty"),
								timeout = 3,
							})
							return
						end

						-- Build fields array for editCatalogFromInput
						-- [1]=title, [2]=url, [3]=username, [4]=password, [5]=raw_names, [6]=sync, [7]=sync_dir
						local new_fields = {
							text_fields[1],                               -- title
							validated_url_or_error,                       -- url (validated)
							text_fields[3],                               -- username
							text_fields[4],                               -- password
							check_button_raw_names.checked or nil,        -- raw_names
							check_button_sync_catalog.checked or nil,     -- sync
							text_fields[5],                               -- sync_dir
						}
						browser:editCatalogFromInput(new_fields, item)
						UIManager:close(dialog)
					end,
				},
			},
		},
	}
	check_button_raw_names = CheckButton:new {
		text = _("Use server filenames"),
		checked = item and item.raw_names,
		parent = dialog,
	}
	check_button_sync_catalog = CheckButton:new {
		text = _("Sync catalog"),
		checked = item and item.sync,
		parent = dialog,
	}
	dialog:addWidget(check_button_raw_names)
	dialog:addWidget(check_button_sync_catalog)

	return dialog
end

-- Build the add sub-catalog dialog
-- @param browser table OPDSBrowser instance
-- @param item_url string Catalog URL to add
-- @return table MultiInputDialog widget
function OPDSMenuBuilder.buildSubCatalogDialog(browser, item_url)
	local util = require("util")

	-- Compute default catalog name
	local default_name = browser.root_catalog_title or ""
	if browser.catalog_title then
		default_name = default_name .. " - " .. browser.catalog_title
	end

	-- Compute default sync_dir: parent catalog's sync_dir / current feed title
	-- Falls back to global sync_dir if no per-catalog sync_dir is set
	local parent_sync_dir = browser.root_catalog_sync_dir or browser.settings.sync_dir
	local default_sync_dir = ""
	if parent_sync_dir and browser.catalog_title then
		local sanitized_title = util.replaceAllInvalidChars(browser.catalog_title)
		default_sync_dir = parent_sync_dir .. "/" .. sanitized_title
	elseif parent_sync_dir then
		default_sync_dir = parent_sync_dir
	end

	local fields = {
		{
			text = default_name,
			hint = _("Catalog name"),
		},
		{
			text = default_sync_dir ~= "" and default_sync_dir or nil,
			hint = _("Sync directory (optional)"),
		},
	}

	local dialog, check_button_sync_catalog
	dialog = MultiInputDialog:new {
		title = _("Add OPDS catalog"),
		fields = fields,
		buttons = {
			{
				{
					text = _("Cancel"),
					id = "close",
					callback = function()
						UIManager:close(dialog)
					end,
				},
				{
					text = _("Save"),
					is_enter_default = true,
					callback = function()
						local text_fields = dialog:getFields()
						local name = text_fields[1]
						if name == "" then return end

						-- Create sync directory if specified and doesn't exist
						local sync_dir = text_fields[2]
						if sync_dir and sync_dir ~= "" then
							util.makePath(sync_dir)
						end

						UIManager:close(dialog)
						local save_fields = {
							name,                                         -- [1] title
							item_url,                                     -- [2] url
							browser.root_catalog_username,                -- [3] username
							browser.root_catalog_password,                -- [4] password
							browser.root_catalog_raw_names,               -- [5] raw_names
							check_button_sync_catalog.checked or nil,     -- [6] sync
							sync_dir,                                     -- [7] sync_dir
						}
						browser:editCatalogFromInput(save_fields, nil, true)
					end,
				},
			},
		},
	}
	check_button_sync_catalog = CheckButton:new {
		text = _("Sync catalog"),
		checked = false,
		parent = dialog,
	}
	dialog:addWidget(check_button_sync_catalog)

	return dialog
end

-- Build the search catalog dialog
-- @param browser table OPDSBrowser instance
-- @param item_url string Search URL template
-- @return table InputDialog widget
function OPDSMenuBuilder.buildSearchDialog(browser, item_url)
	local util = require("util")

	local dialog
	dialog = InputDialog:new {
		title = _("Search OPDS catalog"),
		input_hint = _("Alexandre Dumas"),
		description = _("%s in url will be replaced by your input"),
		buttons = {
			{
				{
					text = _("Cancel"),
					id = "close",
					callback = function()
						UIManager:close(dialog)
					end,
				},
				{
					text = _("Search"),
					is_enter_default = true,
					callback = function()
						UIManager:close(dialog)
						browser.catalog_title = _("Search results")
						local search_str = util.urlEncode(dialog:getInputText())
						local search_url = item_url:gsub("%%s", function() return search_str end)
						browser:updateCatalog(search_url)
					end,
				},
			},
		},
	}

	return dialog
end

-- Check if current item table has covers
-- @param item_table table Table of catalog items
-- @return boolean True if any item has a cover
function OPDSMenuBuilder.hasCovers(item_table)
	for _, item in ipairs(item_table or {}) do
		if item.cover_url then
			return true
		end
	end
	return false
end

return OPDSMenuBuilder
